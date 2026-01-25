# Biometric Authentication Implementation Plan

## Problem Statement

Users find TOTP-based login cumbersome. The current session management relies
solely on token expiration, forcing frequent re-authentication. We need a way
to keep users logged in longer while maintaining security through local device
authentication (PIN, Touch ID, Face ID).

## Solution Overview

Implement **local authentication** as a secondary security layer that:

1. Protects the app when returning from background/lock screen
2. Allows backend tokens to have longer lifetimes (reduced TOTP friction)
3. Provides fallback options (PIN) when biometrics unavailable
4. Maintains security without requiring network connectivity

```text
┌─────────────────────────────────────────────────────────────────┐
│                        AUTH FLOW OVERVIEW                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   First Launch          Returning User         App Resume       │
│   ─────────────         ──────────────         ──────────────   │
│        │                      │                      │          │
│        ▼                      ▼                      ▼          │
│   ┌─────────┐           ┌─────────┐           ┌─────────┐       │
│   │  OIDC   │           │Check if │           │Check if │       │
│   │  Login  │           │tokens ok│           │tokens ok│       │
│   └────┬────┘           └────┬────┘           └────┬────┘       │
│        │                     │                     │            │
│        ▼                     ▼ valid               ▼ valid      │
│   ┌─────────┐           ┌─────────┐           ┌─────────┐       │
│   │  Setup  │           │ Biometric│          │ Biometric│      │
│   │  PIN +  │           │  or PIN  │          │  or PIN  │      │
│   │Biometric│           └────┬────┘           └────┬────┘       │
│   └────┬────┘                │                     │            │
│        │                     ▼                     ▼            │
│        ▼                ┌─────────┐           ┌─────────┐       │
│   ┌─────────┐           │  Token  │           │   App   │       │
│   │   App   │           │ Refresh │           │ Unlocked│       │
│   │ Unlocked│           │(if needed)          └─────────┘       │
│   └─────────┘           └────┬────┘                             │
│                              │                                  │
│        ▼ expired             ▼                                  │
│   ┌─────────┐           ┌─────────┐                             │
│   │  OIDC   │           │   App   │                             │
│   │  Login  │           │ Unlocked│                             │
│   └─────────┘           └─────────┘                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Security Model

### Threat Model & Limitations

**What this protects against:**

- Casual access by someone who picks up an unlocked device
- Shoulder surfing (biometric is invisible, PIN is brief)
- App switcher snooping (privacy curtain)

**What this does NOT protect against:**

- Jailbroken/rooted device with debugger attached
- Malware with root access reading secure storage
- Physical device compromise with forensic tools

### UI Lock vs Data Encryption Trade-off

This implementation uses a **UI lock** approach, not data encryption:

| Approach | Security | Complexity | UX |
|----------|----------|------------|-----|
| **UI Lock** (this plan) | Medium | Low | Smooth |
| **PIN-encrypted tokens** | High | High | Slower unlock |

**Rationale:** For this use case (convenience over TOTP), UI lock provides
sufficient security. The tokens remain protected by OS keychain/keystore
encryption. A future phase could add PIN-based token encryption for
higher-security deployments.

**Acknowledged risk:** If an attacker bypasses the UI layer (debugger, code
injection on compromised device), they could access tokens without the PIN.
This is acceptable for our threat model.

### Biometric Security Class

On Android, biometrics vary in strength:

- **Class 3 (Strong):** Hardware-backed, spoof-resistant (fingerprint, 3D face)
- **Class 2 (Weak):** Software-based, spoofable (2D face unlock)

**Requirement:** Only accept Class 3 (strong) biometrics via `local_auth`
configuration. This prevents attacks using photos against weak face unlock.

### PIN is Mandatory

**Decision:** PIN setup is REQUIRED. Users cannot skip PIN and use
biometrics-only.

**Rationale:** Biometrics can fail (sensor damage, enrollment changes, OS
updates invalidating keys). Without a PIN fallback, users would be permanently
locked out with no recovery path except wiping the app (losing their session).

Users can:

- Use PIN only (no biometrics)
- Use biometrics + PIN fallback (recommended)

Users cannot:

- Use biometrics only (no fallback)
- Skip local auth entirely after setup prompt (they can disable later in
  settings, but must set up once)

## Architecture Design

### New Components

```text
lib/
├── core/
│   ├── auth/
│   │   └── local_auth/
│   │       ├── local_auth_repository.dart   # Combines local_auth + storage
│   │       ├── local_auth_state.dart        # Locked/Unlocked states
│   │       ├── local_auth_notifier.dart     # Riverpod state management
│   │       ├── local_auth_provider.dart     # Provider definitions
│   │       ├── local_auth_settings.dart     # User preferences
│   │       └── pin_storage.dart             # Secure PIN hash storage
│   └── providers/
│       └── (existing)
├── features/
│   ├── local_auth/
│   │   ├── lock_screen.dart                 # Combined biometric/PIN screen
│   │   ├── pin_entry_screen.dart            # PIN entry/verification
│   │   ├── pin_setup_screen.dart            # Initial PIN setup
│   │   ├── local_auth_setup_screen.dart     # Method selection
│   │   └── widgets/
│   │       ├── pin_keypad.dart
│   │       ├── pin_dots.dart
│   │       └── privacy_curtain.dart         # App switcher protection
│   └── settings/
│       └── (add biometric settings section)
```

### State Machine

```dart
/// Local authentication state machine.
///
/// CRITICAL: Default/initial state MUST be [checking] which blocks UI
/// until storage confirms actual state (fail-closed design).
sealed class LocalAuthState {
  /// Initial state - checking storage for persisted state.
  /// UI should show loading/splash, NOT app content.
  const factory LocalAuthState.checking() = Checking;

  /// User hasn't set up local auth yet (confirmed from storage).
  const factory LocalAuthState.notConfigured() = NotConfigured;

  /// Local auth configured, app is locked.
  const factory LocalAuthState.locked({
    required LocalAuthMethod method,
    required int failedAttempts,
    DateTime? lockedUntil,  // Non-null during cooldown
  }) = Locked;

  /// Biometric/PIN authentication in progress.
  const factory LocalAuthState.authenticating({
    required LocalAuthMethod method,
  }) = Authenticating;

  /// Temporary lockout due to failed attempts.
  const factory LocalAuthState.cooldown({
    required DateTime until,
    required int failedAttempts,
  }) = Cooldown;

  /// Local auth passed, verifying token validity.
  /// UI should show loading indicator, NOT app content.
  const factory LocalAuthState.unlocking() = Unlocking;

  /// Local auth configured, app is unlocked and token verified.
  const factory LocalAuthState.unlocked({
    required LocalAuthMethod method,
    required DateTime unlockedAt,
  }) = Unlocked;

  /// Biometric enrollment changed - require PIN to re-verify.
  /// Shows "Forgot PIN? Sign Out" option.
  const factory LocalAuthState.reconfigureRequired({
    required String reason,
  }) = ReconfigureRequired;

  /// User explicitly disabled local auth (via settings, after initial setup).
  const factory LocalAuthState.disabled() = Disabled;

  /// Storage corrupted or unreadable - force user to sign out and reset.
  const factory LocalAuthState.storageError({
    required String message,
  }) = StorageError;
}

enum LocalAuthMethod {
  pin,        // 6-digit PIN only
  both,       // Biometric with PIN fallback (recommended)
  // NOTE: biometric-only is NOT allowed - PIN is mandatory
}
```

### Persisted State

The following MUST persist in `FlutterSecureStorage` to survive app kill:

```dart
class PersistedLocalAuthState {
  final bool isConfigured;
  final bool isDisabled;           // User disabled via settings
  final LocalAuthMethod? method;
  final bool isLocked;             // Restore locked state on launch
  final int failedAttempts;        // CRITICAL: prevents restart brute force
  final DateTime? cooldownUntil;   // Persist cooldown across restarts
  final DateTime? lastUnlockedAt;
}
```

### Storage Key Namespacing

**CRITICAL:** Local auth storage keys MUST be namespaced per-user to prevent:

- Account switching inheriting wrong PIN
- Multi-tenant environments sharing security state
- Partial sign-out leaving orphaned PIN data

```dart
class LocalAuthStorage {
  final FlutterSecureStorage _storage;
  late final String _namespacePrefix;

  LocalAuthStorage({
    required FlutterSecureStorage storage,
    required String issuerId,
    required String subject,
  }) : _storage = storage {
    // Generate namespace from stable user identifier
    // Uses issuer + subject claim from ID token
    final hash = sha256.convert(utf8.encode('$issuerId:$subject'));
    _namespacePrefix = hash.toString().substring(0, 16); // 16-char prefix
  }

  String _key(String baseKey) => 'local_auth_${_namespacePrefix}_$baseKey';

  // All storage operations use namespaced keys:
  Future<void> savePinHash(String hash) =>
      _storage.write(key: _key('pin_hash'), value: hash);

  Future<String?> readPinHash() =>
      _storage.read(key: _key('pin_hash'));

  Future<void> savePinSalt(String salt) =>
      _storage.write(key: _key('pin_salt'), value: salt);

  // ... other methods follow same pattern
}
```

**On startup:** Verify namespace matches current auth context. If mismatch
(different user logged in), clear local auth state and require fresh setup.

### Integration Points

| Component | Change Required |
|-----------|-----------------|
| `AuthNotifier` | Pause token refresh while `LocalAuthState.locked` |
| `app_router.dart` | Add lock screen guard (runs BEFORE auth guard) |
| `main.dart` | Add `AppLifecycleListener` with privacy curtain |
| `SettingsScreen` | Add biometric/PIN configuration section |
| `LocalAuthStorage` | New class for local auth persistence |

### Router Guard Precedence

Guards evaluate in this order (first match wins):

```dart
redirect: (context, state) {
  final localAuth = ref.read(localAuthProvider);
  final auth = ref.read(authProvider);

  // 0. FAIL-CLOSED: Block ALL navigation while checking storage
  // This prevents content flash before security state is known
  if (localAuth is Checking || localAuth is Unlocking) {
    return '/splash';  // Dedicated loading screen, NOT app content
  }

  // 1. Storage error - force sign out (highest priority error state)
  if (localAuth is StorageError) {
    return '/local-auth/error';  // Shows "Reset" button
  }

  // 2. Not authenticated at all → OIDC login
  // This handles: never logged in, or already signed out
  if (auth is! Authenticated && auth is! NoAuthRequired) {
    return '/login';
  }

  // 3. CRITICAL: Local auth lock BEFORE token expiry check
  // This prevents SSO bypass attack where attacker waits for token
  // expiry, then leverages browser's cached IdP session cookie.
  // User MUST authenticate locally first, even if tokens are expired.
  if (localAuth is Locked || localAuth is Cooldown) {
    return '/lock';
  }

  // 4. Biometric reconfiguration required
  if (localAuth is ReconfigureRequired) {
    return '/lock';  // Shows PIN entry + "Forgot PIN? Sign Out"
  }

  // 5. NOW check token validity (after local auth passed)
  // If tokens expired, lock screen has already been shown,
  // so we're safe to attempt refresh/re-login
  if (auth is Authenticated && auth.isExpired) {
    // Attempt refresh first; if fails, then OIDC login
    // At this point user has already passed local auth
    return '/login';
  }

  // 6. Local auth setup (after OIDC, before app access)
  if (auth is Authenticated && localAuth is NotConfigured) {
    return '/local-auth/setup';
  }

  // 7. Local auth disabled - allow access
  if (localAuth is Disabled) {
    return null;
  }

  return null; // Allow navigation
}
```

### AuthNotifier Integration Contract

```dart
// In AuthNotifier - pause refresh while locked
Future<RefreshResult> tryRefresh() async {
  final localAuth = ref.read(localAuthProvider);

  // Don't attempt network calls while UI is locked
  if (localAuth is Locked || localAuth is Cooldown) {
    return RefreshResult.deferred;
  }

  // Existing refresh logic...
}

// Hook called after successful OIDC authentication
void _onAuthenticated() {
  final localAuth = ref.read(localAuthProvider);
  if (localAuth is NotConfigured) {
    // Router will redirect to /local-auth/setup
  }
}
```

### LocalAuthNotifier Unlock Contract

```dart
/// Unlocking state - PIN/biometric passed but token not yet verified.
/// UI should show loading indicator, NOT app content.
const factory LocalAuthState.unlocking() = Unlocking;

// In LocalAuthNotifier - two-phase unlock to prevent TOCTOU
Future<void> unlock() async {
  // Phase 1: Local auth passed, but don't show app content yet
  state = const LocalAuthState.unlocking();

  await _storage.saveState(isLocked: false, failedAttempts: 0);

  // Phase 2: Verify token is still valid before showing content
  // This prevents data flash if tokens expired during lock
  final refreshResult = await ref.read(authProvider.notifier).tryRefresh();

  if (refreshResult == RefreshResult.success ||
      refreshResult == RefreshResult.notNeeded) {
    // Token valid - fully unlock
    state = LocalAuthState.unlocked(
      method: _currentMethod,
      unlockedAt: DateTime.now(),
    );
  } else {
    // Token expired/invalid - will redirect to OIDC via router guard
    // Keep unlocked state so user doesn't see lock screen again after login
    state = LocalAuthState.unlocked(
      method: _currentMethod,
      unlockedAt: DateTime.now(),
    );
  }
}

// Handle sign-out: clear local auth config when tokens are cleared
void onSignOut() {
  // Decision: Local auth config is PER-USER, not global
  // When user signs out, clear their PIN/biometric config
  _storage.clearAll();
  state = const LocalAuthState.notConfigured();
}

// Handle issuer/backend switch
void onIssuerChanged() {
  // Same as signOut - treat as new authentication context
  onSignOut();
}
```

**Router must handle `Unlocking` state:**

```dart
if (localAuth is Unlocking) {
  return '/splash';  // Show loading, NOT app content
}
```

### Privacy Curtain vs Lock Timing

**Important distinction:**

- **Privacy curtain:** Shows IMMEDIATELY on `inactive` state (before iOS
  screenshots app switcher). This is VISUAL ONLY - no auth state change.
- **Lock logic:** Only engages if background duration exceeds grace period.
  Triggered on `resumed`, not `inactive`.

**Race condition warning:** When `local_auth` triggers the native biometric
prompt, the Flutter app may transition to `inactive` state. The privacy curtain
could flash while the user is authenticating.

**Solution:** Check if biometric authentication is in progress before showing
the curtain:

```dart
case AppLifecycleState.inactive:
  final localAuth = ref.read(localAuthProvider);
  // Don't show curtain during intentional biometric prompt
  if (localAuth is! Authenticating) {
    ref.read(privacyCurtainProvider.notifier).show();
  }
  return;
```

```text
User switches to another app:
  1. AppLifecycleState.inactive → Show privacy curtain (instant)
  2. AppLifecycleState.paused → Record timestamp
  3. User returns (< grace period)
  4. AppLifecycleState.resumed → Hide curtain, NO lock
```

```text
User switches to another app:
  1. AppLifecycleState.inactive → Show privacy curtain (instant)
  2. AppLifecycleState.paused → Record timestamp
  3. User returns (> grace period)
  4. AppLifecycleState.resumed → Hide curtain, TRIGGER lock
```

## Implementation Phases

### Phase 1: Core Infrastructure

**Goal:** Establish the foundation for local authentication.

#### Tasks

1. **Add dependencies**

   ```yaml
   dependencies:
     local_auth: ^2.3.0
     cryptography: ^2.7.0  # For PBKDF2 (NOT crypto package)
   ```

2. **Create `LocalAuthRepository`**

   Simplified design (no unnecessary abstraction over `local_auth`):

   ```dart
   class LocalAuthRepository {
     final LocalAuthentication _localAuth;
     final FlutterSecureStorage _storage;

     /// Check biometric availability with strong requirement
     ///
     /// On Android API 30+, sensitiveTransaction enforces Class 3 (strong).
     /// On Android API <30, we cannot distinguish Class 2 vs Class 3.
     /// We allow biometrics on API <30 but document this limitation.
     Future<BiometricStatus> checkBiometrics() async {
       final available = await _localAuth.canCheckBiometrics;
       final types = await _localAuth.getAvailableBiometrics();

       // BiometricType.strong is only reported on Android 30+
       // BiometricType.fingerprint is always considered strong
       // BiometricType.face/iris may be weak on older Android
       final hasStrong = types.contains(BiometricType.strong) ||
                         types.contains(BiometricType.fingerprint);

       return BiometricStatus(
         available: available,
         types: types,
         hasStrong: hasStrong,
         // If device only has weak biometrics, biometric option
         // should be hidden and user forced to PIN-only mode
       );
     }

     /// Authenticate - requires strong biometrics on Android
     Future<bool> authenticate(String reason) async {
       try {
         return await _localAuth.authenticate(
           localizedReason: reason,
           options: const AuthenticationOptions(
             biometricOnly: true,
             stickyAuth: true,
             // sensitiveTransaction: true enforces Class 3 on Android 30+
             sensitiveTransaction: true,
           ),
         );
       } on PlatformException catch (e) {
         // Map specific error codes
         throw _mapPlatformException(e);
       }
     }

     LocalAuthException _mapPlatformException(PlatformException e) {
       // Map local_auth error codes to our exceptions
       return switch (e.code) {
         'NotAvailable' => LocalAuthException.notAvailable,
         'NotEnrolled' => LocalAuthException.notEnrolled,
         'LockedOut' => LocalAuthException.lockedOut,
         'PermanentlyLockedOut' => LocalAuthException.permanentlyLockedOut,
         'PasscodeNotSet' => LocalAuthException.passcodeNotSet,
         'OtherOperatingSystem' => LocalAuthException.notSupported,
         _ => LocalAuthException.unknown(e.message),
       };
     }
   }
   ```

3. **Create `PinStorage` with proper KDF**

   ```dart
   class PinStorage {
     static const _kdfIterations = 100000;
     static const _saltLength = 32;
     static const _hashLength = 32;

     final FlutterSecureStorage _storage;

     /// Store PIN using PBKDF2-SHA256
     /// Runs KDF in isolate to avoid UI jank on slower devices
     Future<void> savePin(String pin) async {
       final salt = _generateSecureRandom(_saltLength);
       // Run expensive KDF off main thread
       // IMPORTANT: Pass primitives only - custom classes are not sendable
       final hash = await Isolate.run(
         () => _deriveKeySync(pin, salt, _kdfIterations),
       );

       await _storage.write(key: 'pin_hash', value: base64Encode(hash));
       await _storage.write(key: 'pin_salt', value: base64Encode(salt));
       await _storage.write(key: 'pin_iterations', value: '$_kdfIterations');

       // NOTE: Dart Strings are immutable and cannot be wiped from memory.
       // The PIN will be garbage collected but may persist in memory briefly.
       // This is an accepted limitation of the Dart runtime.
     }

     /// Verify PIN - constant-time comparison
     /// Returns null on storage corruption (caller should transition to StorageError)
     Future<bool?> verifyPin(String pin) async {
       final storedHashB64 = await _storage.read(key: 'pin_hash');
       final storedSaltB64 = await _storage.read(key: 'pin_salt');
       final iterationsStr = await _storage.read(key: 'pin_iterations');

       if (storedHashB64 == null || storedSaltB64 == null) {
         return null; // Storage corrupted - signal to caller
       }

       // Decode BEFORE comparison to avoid timing leak on invalid base64
       final Uint8List storedHash;
       final Uint8List storedSalt;
       try {
         storedHash = base64Decode(storedHashB64);
         storedSalt = base64Decode(storedSaltB64);
       } catch (_) {
         return null; // Corrupted storage - signal to caller
       }

       // Verify expected lengths before constant-time compare
       if (storedHash.length != _hashLength ||
           storedSalt.length != _saltLength) {
         return null; // Corrupted storage
       }

       final iterations = int.tryParse(iterationsStr ?? '') ?? _kdfIterations;
       final hash = await Isolate.run(
         () => _deriveKeySync(pin, storedSalt, iterations),
       );

       return _constantTimeEquals(hash, storedHash);
     }

     /// Top-level static function for isolate execution
     /// Uses primitives only (String, Uint8List, int) - no custom classes
     static Uint8List _deriveKeySync(
       String pin,
       Uint8List salt,
       int iterations,
     ) {
       final pbkdf2 = Pbkdf2(
         macAlgorithm: Hmac.sha256(),
         iterations: iterations,
         bits: _hashLength * 8,
       );
       final secretKey = pbkdf2.deriveKeySync(
         secretKey: SecretKey(utf8.encode(pin)),
         nonce: salt,
       );
       return Uint8List.fromList(secretKey.extractBytesSync());
     }

     bool _constantTimeEquals(Uint8List a, Uint8List b) {
       if (a.length != b.length) return false;
       var result = 0;
       for (var i = 0; i < a.length; i++) {
         result |= a[i] ^ b[i];
       }
       return result == 0;
     }
   }
   ```

   **Note:** The `verifyPin` method returns `null` on storage corruption.
   The caller (`LocalAuthNotifier`) must handle this by transitioning to
   `StorageError` state, not by treating it as a failed PIN attempt.

4. **Create state management with fail-closed default and error handling**

   ```dart
   class LocalAuthNotifier extends Notifier<LocalAuthState> {
     late final LocalAuthStorage _storage;

     @override
     LocalAuthState build() {
       _storage = ref.read(localAuthStorageProvider);
       // CRITICAL: Start in checking state, not unlocked
       _restorePersistedState();
       return const LocalAuthState.checking();
     }

     Future<void> _restorePersistedState() async {
       final PersistedLocalAuthState? persisted;

       try {
         persisted = await _storage.loadState();
       } catch (e) {
         // CRITICAL: Storage corrupted/unreadable
         // Do NOT fail open - show error screen with reset option
         state = LocalAuthState.storageError(
           message: 'Unable to read security settings: $e',
         );
         return;
       }

       if (persisted == null || !persisted.isConfigured) {
         state = const LocalAuthState.notConfigured();
         return;
       }

       if (persisted.isDisabled) {
         state = const LocalAuthState.disabled();
         return;
       }

       // Check if still in cooldown
       if (persisted.cooldownUntil != null &&
           DateTime.now().isBefore(persisted.cooldownUntil!)) {
         state = LocalAuthState.cooldown(
           until: persisted.cooldownUntil!,
           failedAttempts: persisted.failedAttempts,
         );
         return;
       }

       // Restore locked state (fail-closed)
       // Even if previously unlocked, lock on app relaunch
       state = LocalAuthState.locked(
         method: persisted.method!,
         failedAttempts: persisted.failedAttempts,
       );
     }
   }
   ```

#### Platform Configuration

**iOS (`ios/Runner/Info.plist`):**

```xml
<key>NSFaceIDUsageDescription</key>
<string>Unlock Soliplex with Face ID for quick access</string>
```

**macOS (ALL entitlement files):**

Update these three files:

- `macos/Runner/DebugProfile.entitlements`
- `macos/Runner/Debug.entitlements`
- `macos/Runner/Release.entitlements`

```xml
<key>com.apple.security.device.biometric</key>
<true/>
```

**macOS Keychain accessibility (`flutter_secure_storage` options):**

```dart
const storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
  mOptions: MacOsOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
```

**Android (`android/app/src/main/AndroidManifest.xml`):**

```xml
<!-- For Android 28+ -->
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<!-- For Android 23-27 (backward compatibility) -->
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
```

#### Files to Create

- `lib/core/auth/local_auth/local_auth_repository.dart`
- `lib/core/auth/local_auth/local_auth_state.dart`
- `lib/core/auth/local_auth/local_auth_notifier.dart`
- `lib/core/auth/local_auth/local_auth_provider.dart`
- `lib/core/auth/local_auth/local_auth_storage.dart`
- `lib/core/auth/local_auth/local_auth_exception.dart`
- `lib/core/auth/local_auth/pin_storage.dart`

#### Acceptance Criteria

- [ ] `local_auth` and `cryptography` packages added
- [ ] All three macOS entitlement files configured for biometrics
- [ ] Can detect biometric availability (strong only on Android)
- [ ] PIN stored with PBKDF2, salt persisted, iterations stored
- [ ] KDF runs in isolate (not on UI thread)
- [ ] Failed attempt counter persists in secure storage
- [ ] State defaults to `checking` then `locked` (fail-closed)
- [ ] Storage read failure → `StorageError` state (not crash or fail-open)

### Phase 2: Lock Screen UI

**Goal:** Build the user-facing lock screens.

#### Tasks

1. **Lock screen with biometric + PIN**
   - Auto-triggers biometric on mount (if enabled)
   - "Use PIN" button visible immediately
   - **"Forgot PIN? Sign Out"** link at bottom (clears tokens, OIDC re-login)
   - Shows remaining cooldown time if in lockout
   - Also shown for `ReconfigureRequired` state (with explanation)

2. **PIN entry screen**
   - 6-digit PIN input (numeric keypad)
   - Shows dots for entered digits
   - Shake animation on wrong PIN - **AFTER** storage write completes
   - Shows "X attempts remaining" warning
   - Disabled during cooldown with countdown

3. **PIN setup screen**
   - Enter PIN twice to confirm
   - PIN strength validation:
     - No sequential digits (123456, 654321)
     - No repeated digits (111111, 000000)
     - No common PINs (123123, 112233)
   - Back navigation to cancel setup
   - **Must complete atomically** - partial setup treated as not configured

4. **Local auth setup screen**
   - Shown after successful OIDC login (first time)
   - Options: "Enable Face ID + PIN", "Use PIN Only"
   - **No "Skip" option** - PIN is mandatory
   - Explains benefits of local auth
   - Can disable later in settings (requires PIN verification)

5. **Storage error screen**
   - Shown when storage is corrupted
   - Explains the problem
   - Single action: "Sign Out & Reset"
   - Clears all local auth and token data

6. **Privacy curtain widget**
   - Blur/solid overlay shown on `AppLifecycleState.inactive`
   - Prevents iOS app switcher screenshot exposure
   - Removed on `resumed` after auth check

#### Files to Create

- `lib/features/local_auth/lock_screen.dart`
- `lib/features/local_auth/pin_entry_screen.dart`
- `lib/features/local_auth/pin_setup_screen.dart`
- `lib/features/local_auth/local_auth_setup_screen.dart`
- `lib/features/local_auth/storage_error_screen.dart`
- `lib/features/local_auth/widgets/pin_keypad.dart`
- `lib/features/local_auth/widgets/pin_dots.dart`
- `lib/features/local_auth/widgets/privacy_curtain.dart`

#### Acceptance Criteria

- [ ] Biometric prompt triggers native dialog
- [ ] PIN entry works with visual feedback
- [ ] PIN setup validates against weak patterns
- [ ] PIN setup is atomic (no half-configured state)
- [ ] "Forgot PIN? Sign Out" works correctly
- [ ] "Forgot PIN? Sign Out" shown on ReconfigureRequired screen
- [ ] Storage error screen shows reset option
- [ ] Privacy curtain shows on `inactive` state
- [ ] UI feedback (shake) waits for storage write to complete
- [ ] All screens follow app design system

### Phase 3: App Lifecycle Integration

**Goal:** Lock app appropriately on background/resume.

#### Tasks

1. **Add `AppLifecycleListener` in `main.dart`**

   ```dart
   class AppLifecycleObserver extends WidgetsBindingObserver {
     final WidgetRef ref;
     DateTime? _pausedAt;

     @override
     void didChangeAppLifecycleState(AppLifecycleState state) {
       switch (state) {
         case AppLifecycleState.inactive:
           // Show privacy curtain IMMEDIATELY (before iOS screenshot)
           // But NOT during intentional biometric prompts
           final localAuth = ref.read(localAuthProvider);
           if (localAuth is! Authenticating) {
             ref.read(privacyCurtainProvider.notifier).show();
           }
           return;

         case AppLifecycleState.paused:
           _pausedAt = DateTime.now();
           return;

         case AppLifecycleState.resumed:
           ref.read(privacyCurtainProvider.notifier).hide();
           _checkLockRequired();
           return;

         case AppLifecycleState.detached:
           // macOS: window closed but process alive
           // Treat as paused
           _pausedAt ??= DateTime.now();
           return;

         case AppLifecycleState.hidden:
           // Ignore
           return;
       }
     }

     void _checkLockRequired() {
       if (_pausedAt == null) return;

       final settings = ref.read(localAuthSettingsProvider);
       final pauseDuration = DateTime.now().difference(_pausedAt!);
       _pausedAt = null;

       // CRITICAL: Detect clock manipulation (time travel attack)
       // If duration is negative, clock was set backwards → lock immediately
       if (pauseDuration.isNegative) {
         ref.read(localAuthProvider.notifier).lock();
         return;
       }

       // Also detect suspiciously large jumps (>24 hours) which may
       // indicate clock manipulation or device was off for extended period
       if (pauseDuration > const Duration(hours: 24)) {
         ref.read(localAuthProvider.notifier).lock();
         return;
       }

       if (pauseDuration > settings.lockAfterDuration) {
         ref.read(localAuthProvider.notifier).lock();
       }
     }
   }
   ```

   **Note on clock attacks:** Pure Dart has no monotonic clock API.
   For maximum security, consider platform channels to access
   `clock_gettime(CLOCK_BOOTTIME)` (Android) or `mach_absolute_time()` (iOS).
   The negative-duration check is a pragmatic defense for most cases.

2. **Configure lock timing settings**
   - Lock after 15 seconds (for password manager switching)
   - Lock after 1 minute (default - balances security/convenience)
   - Lock after 5 minutes
   - Lock immediately (not recommended)
   - Never lock (not recommended, requires confirmation)

3. **Router guard for lock screen**
   - Runs BEFORE auth guard (see precedence section above)
   - Checks token validity first to avoid double-auth UX nightmare

4. **Persist lock state for app kill scenario**

   ```dart
   Future<void> lock() async {
     // IMPORTANT: Preserve existing failedAttempts when already locked
     // This prevents users from background/resume cycling to reset lockout
     final existingAttempts = switch (state) {
       Locked(:final failedAttempts) => failedAttempts,
       Cooldown(:final failedAttempts) => failedAttempts,
       _ => 0,
     };

     state = LocalAuthState.locked(
       method: _currentMethod,
       failedAttempts: existingAttempts,
     );
     await _storage.saveState(isLocked: true, failedAttempts: existingAttempts);
   }
   ```

   **Note on "Never lock" setting:** Even if the user selects "Never lock",
   the app will still start locked on relaunch (fail-closed). "Never lock"
   only affects the grace period during the current session - it does NOT
   persist an unlocked state across app restarts.

#### Files to Modify

- `lib/main.dart` - Add lifecycle observer
- `lib/core/router/app_router.dart` - Add lock screen guard with precedence
- `lib/core/auth/local_auth/local_auth_notifier.dart` - Handle lifecycle
- `lib/core/auth/auth_notifier.dart` - Pause refresh while locked

#### Acceptance Criteria

- [ ] Privacy curtain shows on `inactive` (before iOS screenshot)
- [ ] Privacy curtain is VISUAL ONLY (no auth state change on inactive)
- [ ] App locks after configured duration on `resumed`
- [ ] Lock state persists if app killed while locked
- [ ] Lock screen shows BEFORE token expiry check (SSO bypass prevention)
- [ ] Token refresh paused while locked
- [ ] Token refresh triggered immediately after unlock
- [ ] Default grace period is 1 minute (not immediate)

### Phase 4: Settings Integration

**Goal:** Allow users to manage local auth preferences.

#### Tasks

1. **Add settings section in `SettingsScreen`**

   ```dart
   // Security section
   SectionHeader('Security'),
   ListTile(
     title: Text('Biometric Lock'),
     subtitle: Text(biometricEnabled
       ? 'Face ID required to open app'
       : 'Disabled'),
     trailing: Switch(value: biometricEnabled, onChanged: ...),
   ),
   ListTile(
     title: Text('Change PIN'),
     subtitle: Text('Required for biometric fallback'),
     onTap: () => _verifyCurrentPinThen(() => context.push('/settings/pin')),
   ),
   ListTile(
     title: Text('Auto-Lock'),
     subtitle: Text(_formatDuration(settings.lockAfterDuration)),
     onTap: () => _showTimeoutPicker(),
   ),
   if (localAuthEnabled)
     ListTile(
       title: Text('Disable App Lock'),
       textColor: Colors.red,
       onTap: () => _confirmDisable(),
     ),
   ```

2. **Settings model**

   ```dart
   class LocalAuthSettings {
     final bool biometricEnabled;
     final bool pinEnabled;             // Always true (PIN mandatory)
     final Duration lockAfterDuration;
     // NOTE: maxFailedAttempts is NOT configurable - uses hardcoded
     // escalating policy (5→20 attempts with increasing cooldowns)

     static const defaultGracePeriod = Duration(minutes: 1);
   }
   ```

3. **Handle settings changes**
   - Changing PIN requires current PIN verification first
   - Disabling local auth requires PIN verification + confirmation dialog
   - Enabling biometric checks device capability first
   - Show error if no strong biometrics available (Android)

#### Files to Modify

- `lib/features/settings/settings_screen.dart`
- `lib/core/auth/local_auth/local_auth_settings.dart` (new)

#### Acceptance Criteria

- [ ] Users can enable/disable biometric lock
- [ ] Users can change PIN (after verifying current)
- [ ] Users can configure lock timeout
- [ ] Disabling requires PIN + confirmation
- [ ] Settings persist correctly
- [ ] Disabled state persists across app restarts

### Phase 5: Error Handling & Edge Cases

**Goal:** Handle all edge cases gracefully.

#### Tasks

1. **Biometric API error handling**

   | `local_auth` Error Code | Handling |
   |-------------------------|----------|
   | `NotAvailable` | Fall back to PIN only |
   | `NotEnrolled` | Prompt to enroll in Settings, use PIN |
   | `LockedOut` | Show "Too many attempts, use PIN" |
   | `PermanentlyLockedOut` | Force PIN, explain device lockout |
   | `PasscodeNotSet` | Require device passcode first |
   | `OtherOperatingSystem` | Not supported, use PIN |
   | User cancels dialog | Show PIN option |
   | User taps "Use Password" | Switch to PIN entry |

2. **Biometric enrollment changes**
   - Detect via `local_auth` (if supported) or on auth failure
   - Set state to `ReconfigureRequired`
   - Show lock screen with PIN entry + "Forgot PIN? Sign Out"
   - Require PIN verification to re-enable biometrics
   - Explain: "Your biometrics have changed. Enter PIN to continue."

3. **Lockout handling with secure persistence**

   Thresholds (consistent policy):

   - Attempts 1-4: Normal retry
   - Attempt 5: 30-second cooldown
   - Attempts 6-9: 1-minute cooldown each
   - Attempts 10-14: 5-minute cooldown each
   - Attempts 15-19: 15-minute cooldown each
   - Attempt 20+: Force OIDC re-login

   **CRITICAL: Race Condition Prevention**

   Concurrent PIN submissions (rapid tapping, automation) can cause lost
   increments if using `state.failedAttempts + 1`. Use storage as source
   of truth with serialization:

   ```dart
   /// Mutex to prevent concurrent failed attempt recording
   final _attemptLock = Lock(); // from package:synchronized

   Future<void> recordFailedAttempt() async {
     // Serialize all attempt recordings to prevent race conditions
     await _attemptLock.synchronized(() async {
       // Read current count from storage (source of truth)
       final currentAttempts = await _storage.readFailedAttempts() ?? 0;
       final attempts = currentAttempts + 1;

       // Persist IMMEDIATELY to prevent restart attack
       // AWAIT this before showing UI feedback
       await _storage.saveState(failedAttempts: attempts);

       if (attempts >= 20) {
         // Force complete re-login
         await _resetAndSignOut();
         return;
       }

       final cooldown = _cooldownDuration(attempts);
       if (cooldown > Duration.zero) {
         final cooldownEnd = DateTime.now().add(cooldown);
         await _storage.saveState(cooldownUntil: cooldownEnd);

         state = LocalAuthState.cooldown(
           until: cooldownEnd,
           failedAttempts: attempts,
         );
       } else {
         state = LocalAuthState.locked(
           method: _currentMethod,
           failedAttempts: attempts,
         );
       }
     });
   }

   Duration _cooldownDuration(int attempts) {
     if (attempts >= 15) return const Duration(minutes: 15);
     if (attempts >= 10) return const Duration(minutes: 5);
     if (attempts >= 6) return const Duration(minutes: 1);
     if (attempts >= 5) return const Duration(seconds: 30);
     return Duration.zero;
   }
   ```

   **Also disable PIN submit button** while verification is in progress to
   prevent rapid submissions at the UI level.

4. **Token expiry during lock - SSO bypass prevention**

   **IMPORTANT:** Do NOT skip local auth when tokens are expired. This creates
   an SSO bypass attack where an attacker waits for token expiry, then opens
   the app - if we skip local auth, the OIDC flow may auto-authenticate using
   cached browser session cookies.

   **Correct flow:**

   1. User opens app with expired tokens
   2. Lock screen shows (local auth required)
   3. User enters PIN or uses biometric
   4. `unlock()` transitions to `Unlocking` state
   5. Token refresh attempted - fails (expired)
   6. Router redirects to OIDC login
   7. User completes OIDC (may require re-entering IdP credentials)

   The lock screen ALWAYS shows first, regardless of token state. Token validity
   is only checked AFTER local auth passes (in the `unlock()` method).

5. **"Forgot PIN" recovery**
   - Shows on lock screen (always visible, not just after failures)
   - Confirmation dialog: "This will sign you out. Continue?"
   - Clears local auth state AND tokens
   - Redirects to OIDC login

6. **Concurrent biometric calls**
   - `local_auth` + `stickyAuth` can re-prompt after app switch
   - Guard with flag to prevent multiple simultaneous `authenticate` calls

   ```dart
   bool _biometricInProgress = false;

   Future<void> _triggerBiometric() async {
     if (_biometricInProgress) return;
     _biometricInProgress = true;
     try {
       final result = await _repository.authenticate(...);
       // handle result
     } finally {
       _biometricInProgress = false;
     }
   }
   ```

#### Files to Modify

- `lib/core/auth/local_auth/local_auth_notifier.dart`
- `lib/features/local_auth/lock_screen.dart`
- `lib/features/local_auth/pin_entry_screen.dart`

#### Acceptance Criteria

- [ ] All biometric error codes have explicit handling (mapped enum)
- [ ] Enrollment changes detected and handled
- [ ] Lockout counter persists across app restarts
- [ ] Cooldown timestamp persists across app restarts
- [ ] Escalating cooldown durations work (5/6/10/15/20 thresholds)
- [ ] Expired tokens: local auth first, THEN OIDC (SSO bypass prevention)
- [ ] "Forgot PIN" clears state and signs out
- [ ] UI feedback waits for storage write (await before shake animation)
- [ ] No concurrent biometric dialogs

### Phase 6: Testing & Polish

**Goal:** Ensure reliability and good UX.

#### Tasks

1. **Unit tests**
   - `LocalAuthNotifier` state transitions (all states)
   - `PinStorage` hash/verify with known test vectors
   - Cooldown timer calculations
   - Settings persistence
   - Storage error handling

2. **Widget tests**
   - PIN entry screen (input, shake, lockout display)
   - Lock screen (biometric trigger, PIN fallback, forgot PIN)
   - Privacy curtain (show/hide)
   - Settings section

3. **Integration tests**
   - Full lock/unlock flow
   - App lifecycle transitions (mock lifecycle events)
   - Token refresh after unlock
   - Failed attempt persistence across "app kill" (provider reset)

4. **Security-focused tests**
   - Verify fail-closed: default state is `checking`/`locked`
   - Verify storage error: mock storage throw → `StorageError` state
   - Verify counter persists: simulate restart mid-lockout
   - Verify salt uniqueness: two `savePin` calls produce different salts
   - Verify constant-time logic: no early returns in comparison

5. **Manual testing checklist**
   - [ ] Fresh install: OIDC → setup flow works (no skip option)
   - [ ] Kill app while locked: restores locked state
   - [ ] Kill app mid-cooldown: cooldown persists
   - [ ] Wrong PIN 5x: 30-second cooldown starts
   - [ ] Wrong PIN 20x: forced OIDC re-login
   - [ ] Biometric cancel: shows PIN option
   - [ ] Background 1 min: locks on resume
   - [ ] Background 10 sec: no lock (grace period)
   - [ ] Token expired while locked: goes to OIDC (no double-auth)
   - [ ] Disable local auth: requires PIN + confirmation
   - [ ] iOS app switcher: shows blur, not content
   - [ ] Forgot PIN: signs out completely
   - [ ] Storage corruption: shows error screen with reset button
   - [ ] Biometric enrollment change: shows PIN prompt

#### Files to Create

- `test/core/auth/local_auth/local_auth_notifier_test.dart`
- `test/core/auth/local_auth/pin_storage_test.dart`
- `test/core/auth/local_auth/local_auth_storage_test.dart`
- `test/features/local_auth/lock_screen_test.dart`
- `test/features/local_auth/pin_entry_screen_test.dart`

#### Acceptance Criteria

- [ ] 85%+ code coverage for local_auth module
- [ ] All tests pass
- [ ] No analyzer warnings
- [ ] Security tests verify fail-closed behavior
- [ ] Storage corruption test verifies error state (not hang)

## Dependencies

### New Packages

| Package | Version | Purpose |
|---------|---------|---------|
| `local_auth` | ^2.3.0 | Biometric authentication |
| `cryptography` | ^2.7.0 | PBKDF2 key derivation |

### Platform Configuration Summary

| Platform | Configuration |
|----------|---------------|
| iOS | `NSFaceIDUsageDescription` in Info.plist |
| macOS | `com.apple.security.device.biometric` in ALL entitlements |
| macOS | Keychain `first_unlock_this_device` accessibility |
| Android | `USE_BIOMETRIC` permission (API 28+) |
| Android | `USE_FINGERPRINT` permission (API 23-27) |
| Android | Strong biometrics only (Class 3 via `sensitiveTransaction`) |

## Security Considerations

1. **PIN Storage**
   - PBKDF2-SHA256 with 100,000 iterations
   - 32-byte random salt per PIN
   - Salt and iteration count stored alongside hash
   - Constant-time comparison to prevent timing attacks
   - KDF runs in isolate (no UI jank)
   - Note: Dart Strings cannot be wiped (immutable); accepted limitation

2. **Fail-Closed Design**
   - Initial state is `checking`, NOT `unlocked`
   - Storage read failure → `StorageError` state (not crash or open)
   - App kill during locked state → restore locked
   - Any ambiguous state → locked

3. **Brute Force Protection**
   - Failed attempts counter in secure storage
   - Persists across app restarts (prevents reset attack)
   - Storage write completes BEFORE UI feedback
   - Escalating cooldowns: 30s → 1m → 5m → 15m
   - After 20 attempts: force OIDC re-login

4. **Biometric Security**
   - Android: require Class 3 (strong) via `sensitiveTransaction: true`
   - Detect enrollment changes → require PIN re-verification
   - Biometric confirms device ownership, not identity
   - Guard against concurrent authenticate calls

5. **Privacy Protection**
   - Privacy curtain on `inactive` (before iOS screenshot)
   - App content never visible in app switcher
   - Consider: screenshot detection (optional, OS-dependent)

6. **Token Security**
   - Tokens remain in OS keychain/keystore
   - Local auth is ADDITIONAL UI layer
   - Token refresh paused while locked
   - Token refresh triggered immediately on unlock
   - Expired tokens bypass local auth (no double-auth)

## Validation Gate

Before considering each phase complete, verify:

### Phase 1 Gate

- [ ] `cryptography` package used (NOT `crypto`)
- [ ] PBKDF2 iterations ≥ 100,000
- [ ] Unit test: two `savePin` calls produce different salts
- [ ] All three macOS entitlement files include biometric permission
- [ ] Keychain accessibility is `first_unlock_this_device`
- [ ] Default state is `checking`, not `unlocked`
- [ ] Unit test: mock storage throw → state is `StorageError`
- [ ] KDF runs via `compute()` (isolate, not main thread)
- [ ] Android uses `sensitiveTransaction: true` for Class 3

### Phase 2 Gate

- [ ] "Forgot PIN / Sign Out" link present on lock screen (always visible)
- [ ] "Forgot PIN / Sign Out" link present on ReconfigureRequired screen
- [ ] PIN validation rejects sequential/repeated/common patterns
- [ ] No "Skip" option on setup screen
- [ ] Privacy curtain widget exists
- [ ] Storage error screen exists with reset action

### Phase 3 Gate

- [ ] Privacy curtain triggers on `inactive` (not just `resumed`)
- [ ] Lock logic triggers on `resumed` (not `inactive`)
- [ ] Lock state persisted before app can be killed
- [ ] `lock()` preserves existing `failedAttempts` (no reset on re-lock)
- [ ] Router checks token validity BEFORE lock screen
- [ ] Default grace period is 1 minute
- [ ] `AuthNotifier.tryRefresh()` checks lock state
- [ ] `LocalAuthNotifier.unlock()` triggers token refresh check

### Phase 4 Gate

- [ ] Disabled state persists across app restarts

### Phase 5 Gate

- [ ] Failed attempt counter survives app restart
- [ ] Cooldown timestamp survives app restart
- [ ] Storage write awaited BEFORE UI feedback (shake animation)
- [ ] Token expiry check happens before biometric prompt
- [ ] All `local_auth` error codes mapped to explicit enum values
- [ ] Concurrent biometric calls guarded with flag

### Phase 6 Gate

- [ ] Test: mock storage failure → `StorageError` state (not hang/crash)
- [ ] Test: reset provider mid-lockout → counter preserved in storage
- [ ] Test: constant-time comparison has no early returns
- [ ] Test: salt differs between two `savePin` calls
- [ ] Manual test: kill app during cooldown → cooldown continues

## Known Limitations & Warnings

These are accepted limitations documented for awareness:

1. **Memory Hygiene (Dart Runtime)**
   - Dart `String` objects are immutable and cannot be zeroed from memory
   - The PIN persists in heap until garbage collection
   - Acceptable for UI lock threat model; precludes "high security" classification
   - Moving PIN processing to Native/FFI would be needed for key derivation use

2. **Device Migration Friction**
   - `FlutterSecureStorage` keys may not survive device migration (Android
     Backup/Restore, certain iCloud restore scenarios)
   - Users migrating devices will likely trigger `StorageError` state
   - This is handled securely (forces reset/re-login) but creates UX friction
   - Support teams should be aware of this scenario

3. **Android API <30 Biometric Strength**
   - `sensitiveTransaction: true` only enforces Class 3 on Android 30+
   - On API <30, we cannot programmatically distinguish Class 2 vs Class 3
   - Fingerprint is always considered strong; face/iris may be weak
   - Devices with only weak biometrics should fall back to PIN-only
   - **UI should explicitly communicate** when device is using weaker biometrics
     (e.g., "Fingerprint available" vs "Face unlock may be less secure")

4. **Lockout Counter Bypass via Reinstall/Clear Data**
   - App-level lockout counter can be reset by:
     - Reinstalling the app (Android clears EncryptedSharedPreferences)
     - Clearing app data in device settings
     - iOS: Keychain persists across reinstall (handled by `clearOnReinstall()`)
   - This is acceptable for UI lock threat model; TEE-managed counters would
     require platform method channels and device-specific implementations
   - Document: "Clearing app data resets lockout protection"

5. **No Root/Jailbreak Detection**
   - This plan explicitly excludes root/jailbreak detection
   - On compromised devices, the UI lock can be bypassed via:
     - Hooking the `LocalAuthState` provider
     - Attaching a debugger
     - Reading tokens directly from storage
   - This is acceptable for the stated threat model

## Open Questions (Resolved)

1. **Web support?**
   - WebAuthn could provide similar UX
   - Lower priority than native platforms
   - **Decision:** Future phase

2. **PIN length?**
   - **Decision:** 6 digits (1M combinations vs 10K for 4 digits)

3. **Biometric-only option?**
   - **Decision:** NOT ALLOWED. PIN is mandatory as fallback.

4. **Should PIN encrypt tokens?**
   - **Decision:** Phase 1 is UI lock. Consider PIN-encrypted tokens in
     future high-security mode.

## NIAP/FedRAMP Compliance Assessment

This section analyzes the plan against NIAP Mobile Device Fundamentals Protection
Profile and FedRAMP controls. **Important:** This plan was designed for convenience
(reducing TOTP friction), not for high-assurance government deployments.

**Scope Clarification:** NIAP MDFPP is primarily a *device* Protection Profile,
not an app PP. Many controls (e.g., FCS_RBG, FPT_AEX) are enforced by the OS,
not the app. This assessment evaluates app-level responsibilities and whether
the app properly *relies on* validated platform services. Controls marked as
"Missing" may be OS-enforced but lack explicit app-level documentation/verification.

### Compliance Status Summary

| Requirement | Standard | Status | Notes |
|-------------|----------|--------|-------|
| FIA_UAU.1 (User Auth) | NIAP | ⚠️ Partial | UI lock, not crypto binding |
| FIA_AFL.1 (Auth Failure) | NIAP | ⚠️ Weak | App-level counter, bypassable via storage clear |
| FDP_DAR.1 (Data at Rest) | NIAP | ❌ Gap | Tokens not PIN-encrypted |
| FCS_CKM.1 (Key Generation) | NIAP | ❌ Gap | Dart crypto not FIPS validated |
| FCS_COP.1 (Crypto Operations) | NIAP | ⚠️ Partial | TLS via NSURLSession, no FIPS mode enforcement |
| FCS_TLSC (TLS Client) | NIAP | ❌ Missing | No cipher suite/version enforcement |
| FCS_RBG (Random Bit Gen) | NIAP | ❌ Missing | No audit of RNG source |
| FAU_GEN (Audit Generation) | NIAP | ❌ Missing | No security event logging |
| FPT_AEX (Anti-Exploitation) | NIAP | ❌ Missing | No root/jailbreak detection |
| IA-5 (Authenticator Mgmt) | FedRAMP | ⚠️ Partial | PBKDF2 used but not FIPS module |
| IA-11 (Re-authentication) | FedRAMP | ✅ Compliant | Configurable lock timeout |
| SC-28 (Data at Rest) | FedRAMP | ❌ Gap | See FDP_DAR.1 |
| AC-7 (Unsuccessful Logons) | FedRAMP | ⚠️ Weak | Counter is app-level, not TEE-managed |
| SC-13 (Crypto Use) | FedRAMP | ❌ Gap | Requires FIPS modules |

**Note:** Ratings downgraded from Round 1 after skeptic review identified that app-level
lockout counters are bypassable on compromised/rooted devices, and several NIAP controls
were missing from initial analysis.

### Critical Compliance Gaps

#### Gap 1: Dart `cryptography` Package Not FIPS 140-2 Validated

**Issue:** The plan uses `cryptography` package for PBKDF2. This is a pure Dart
implementation that has NOT undergone FIPS 140-2/3 validation.

**Impact:** Fails FCS_CKM.1, FCS_COP.1, SC-13 requirements.

**Remediation Options:**

1. **Option A (Recommended for Compliance): Use Platform Crypto**

   Replace Dart crypto with platform method channels:

   ```dart
   // iOS: Use CommonCrypto (part of Security.framework - FIPS validated)
   // Android: Use Android Keystore with StrongBox (FIPS validated TEE)

   // Platform channel interface
   abstract class PlatformCrypto {
     Future<Uint8List> pbkdf2(String password, Uint8List salt, int iterations);
     Future<SecureKeyHandle> generateKey(); // Hardware-backed
   }
   ```

   **Note:** Our existing network layer (`CupertinoHttpClient`) already uses
   NSURLSession, which relies on Apple's Security.framework for TLS - this IS
   FIPS validated. The gap is only in local PIN crypto.

2. **Option B (Simpler but Different UX): Remove App PIN, Use Device Credential**

   Instead of app-level PIN, use OS authentication (device passcode/biometric):

   ```dart
   // iOS: LAContext with LAPolicy.deviceOwnerAuthentication
   // Android: BiometricPrompt.DEVICE_CREDENTIAL
   ```

   This delegates crypto entirely to the OS, which IS FIPS validated.
   **Trade-off:** Loses separate app PIN capability.

#### Gap 2: `first_unlock_this_device` May Not Satisfy FDP_DAR

**Issue:** Keychain accessibility `first_unlock_this_device` means tokens are
decryptable once device is unlocked (even if app is locked).

**Impact:** Partial compliance with FDP_DAR.1, SC-28.

**Remediation Options:**

1. **Change to `whenUnlocked`:**

   ```dart
   const storage = FlutterSecureStorage(
     iOptions: IOSOptions(
       accessibility: KeychainAccessibility.whenUnlocked,
     ),
   );
   ```

   **Trade-off:** Background token refresh won't work while device locked.

2. **Use `SecAccessControl` with Biometric Binding (iOS):**

   ```swift
   // Native Swift via method channel
   let access = SecAccessControlCreateWithFlags(
     nil,
     kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
     .biometryCurrentSet,  // Requires biometric to decrypt
     nil
   )
   ```

   This binds token decryption to biometric authentication at the OS level.

3. **Android: `setUserAuthenticationRequired`:**

   ```kotlin
   val keyGenSpec = KeyGenParameterSpec.Builder(...)
     .setUserAuthenticationRequired(true)
     .setUserAuthenticationValidityDurationSeconds(300)
     .build()
   ```

#### Gap 3: UI Lock Does Not Cryptographically Protect Tokens

**Issue:** This plan uses UI lock, meaning tokens remain decrypted in memory and
accessible via Keychain. An attacker with device access (debugger, jailbreak)
can bypass the UI.

**Impact:** Does not satisfy FDP_DAR.1 fully - tokens are protected by OS
encryption, not app-level encryption.

**Remediation for True FDP_DAR Compliance:**

PIN-encrypt the refresh token itself:

```dart
// Encrypt token with PIN-derived key before storing
final key = await platformCrypto.pbkdf2(pin, salt, 100000);
final encryptedToken = await platformCrypto.aesGcmEncrypt(token, key);
await storage.write(key: 'refresh_token', value: encryptedToken);
```

This requires:

- Platform crypto (Gap 1 remediation)
- Decrypt on PIN entry
- Re-encrypt on PIN change

### Additional Missing NIAP Controls (Round 2 Findings)

The following NIAP Mobile Device Fundamentals PP controls were NOT addressed
in the initial compliance analysis:

| Control | Requirement | Gap |
|---------|-------------|-----|
| FCS_TLSC_EXT | TLS Client Protocol | No cipher suite enforcement, no TLS version pinning |
| FCS_HTTPS_EXT | HTTPS Protocol | No certificate revocation (OCSP/CRL) checking |
| FCS_RBG_EXT | Random Bit Generation | RNG source not audited, no entropy documentation |
| FAU_GEN | Audit Data Generation | No security event logging (failed auth, lockouts) |
| FPT_AEX_EXT | Anti-Exploitation | No ASLR/stack canary verification, no root detection |
| FMT_SMF | Management Functions | "Reset" button bypasses security; admin functions not protected |
| FTA_TAB | Session Termination | No automatic logout on anomaly detection |

**For true NIAP compliance, each of these would need explicit implementation:**

1. **FCS_TLSC_EXT:** Configure `CupertinoHttpClient` to require TLS 1.2+
   with specific FIPS-approved cipher suites (AES-GCM, SHA-256+)
2. **FCS_HTTPS_EXT:** Implement certificate pinning and OCSP stapling
3. **FAU_GEN:** Add security audit logging for auth events, exportable for SIEM
4. **FPT_AEX_EXT:** Add runtime integrity checks; consider anti-tamper library
5. **FMT_SMF:** Require authentication for all security-sensitive operations

### Critical Bug in Existing Implementation

**⚠️ IMMEDIATE FIX REQUIRED before biometric auth implementation:**

The existing `auth_storage_native.dart` is MISSING Android configuration:

```dart
// CURRENT CODE (lib/core/auth/auth_storage_native.dart:45-54)
FlutterSecureStorage _createSecureStorage() {
  return const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    // 🚨 MISSING: aOptions: AndroidOptions(encryptedSharedPreferences: true)
  );
}
```

**Impact:** On Android, without `AndroidOptions(encryptedSharedPreferences: true)`,
the library may use legacy SharedPreferences + RSA keys stored on disk. This
invalidates "hardware-backed" claims for Android.

**Required fix with migration:**

```dart
/// CRITICAL: Migration required before enabling encrypted storage.
/// Existing Android users have tokens in legacy SharedPreferences.
/// Simply enabling encryption will cause 100% forced logout.
Future<void> migrateAndroidStorage() async {
  if (!Platform.isAndroid) return;

  final prefs = await SharedPreferences.getInstance();
  const migrationKey = 'secure_storage_migrated_v1';

  if (prefs.getBool(migrationKey) == true) return; // Already migrated

  // Read from legacy storage (no encryption)
  final legacyStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
  );

  // New encrypted storage
  final newStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  try {
    // Copy all keys from legacy to encrypted
    final allKeys = [
      AuthStorageKeys.accessToken,
      AuthStorageKeys.refreshToken,
      AuthStorageKeys.idToken,
      AuthStorageKeys.expiresAt,
      AuthStorageKeys.issuerId,
      AuthStorageKeys.issuerDiscoveryUrl,
      AuthStorageKeys.clientId,
    ];

    for (final key in allKeys) {
      final value = await legacyStorage.read(key: key);
      if (value != null) {
        await newStorage.write(key: key, value: value);
        await legacyStorage.delete(key: key);
      }
    }

    await prefs.setBool(migrationKey, true);
  } catch (e) {
    // Migration failed - log but continue
    // User may need to re-login, but app won't crash
    debugPrint('Storage migration failed: $e');
  }
}
```

Then update `_createSecureStorage`:

```dart
aOptions: AndroidOptions(encryptedSharedPreferences: true),
```

**Call migration in `main.dart` BEFORE any storage access.**

### Components with Caveats

These components have compliance potential but require configuration/verification:

| Component | Implementation | Status | Caveats |
|-----------|----------------|--------|---------|
| Network TLS | NSURLSession | ⚠️ Conditional | FIPS only if OS in evaluated config, no cipher enforcement |
| iOS Token Storage | Keychain | ⚠️ Conditional | Not Secure Enclave bound; `first_unlock` too permissive |
| Android Token Storage | EncryptedSharedPrefs | ❌ Broken | Missing `AndroidOptions` in current code |
| macOS Token Storage | Keychain | ⚠️ No HW | macOS Keychain has no hardware-backed class |
| Biometric Auth | LAContext/BiometricPrompt | ✅ OS-provided | Relies on OS validation |
| Lockout Policy | App-level counter | ⚠️ Weak | Bypassable by clearing app storage |

**StrongBox Caveat (Android):** Not all devices have StrongBox TEE. Devices
without StrongBox silently fall back to software keystore. The plan should
detect this and either:

- Fail closed (require StrongBox for compliance mode)
- Warn user and document degraded security

### Compliance Upgrade Path

If NIAP/FedRAMP compliance becomes required:

#### Phase A: Minimal Delta (Improve Current Design)

1. Change Keychain accessibility: `first_unlock_this_device` → `whenUnlocked`
2. Add platform method channels for PBKDF2 using CommonCrypto/BoringSSL
3. Document that background refresh requires device unlock

**Effort:** ~2-3 days of platform channel work

#### Phase B: Full Compliance (Hardware-Bound Tokens)

1. Implement `SecAccessControl` with biometric binding (iOS)
2. Implement Keystore `setUserAuthenticationRequired` (Android)
3. PIN-encrypt refresh token (decrypt on unlock)
4. Remove Dart `cryptography` dependency entirely

**Effort:** ~1-2 weeks, requires native development expertise

#### Phase C: Consider Removing App PIN

For maximum compliance with minimal attack surface:

1. Remove app-level PIN entirely
2. Use `local_auth` with `deviceOwnerAuthentication` policy
3. This uses OS passcode/biometric as the only authentication
4. All crypto happens in validated OS modules

**Trade-off:** Users cannot have separate app PIN different from device passcode.

### Compliance Decision for This Plan

**Independent Review Verdicts:**

- Gemini (skeptic): **NEEDS REVISION** - Critical gaps in storage config
- Codex (skeptic): **FAIL** - Missing NIAP controls, FIPS claims unverified

**Recommendation:** Proceed with current plan for convenience use case ONLY,
with explicit acknowledgment that this is NOT compliant with NIAP/FedRAMP.

**What this plan provides:**

1. ✅ Practical security against casual access (shoulder surfing, borrowed device)
2. ✅ Reduction in TOTP friction for legitimate users
3. ✅ Industry-standard UX for app-level authentication
4. ❌ NOT NIAP/FedRAMP compliant
5. ❌ NOT suitable for high-assurance or government deployments

**BEFORE implementing this plan, fix the Android storage bug:**

```dart
// In auth_storage_native.dart - ADD THIS LINE
aOptions: AndroidOptions(encryptedSharedPreferences: true),
```

**For government/regulated deployments:**

This plan creates **compliance debt**. If NIAP/FedRAMP is a future requirement:

1. **Do not ship UI Lock as "compliant"** - it is explicitly not compliant
2. **Consider skipping UI Lock entirely** - go directly to Phase B (PIN-encrypted tokens)
3. **Use Device Credential mode** - delegates all crypto to validated OS modules
4. **Add compliance mode flag** - runtime detection of security capabilities

**Technical debt warning:** Building UI Lock now creates architecture that must
be significantly refactored for Phase B (PIN-encrypted tokens). The synchronous
`loadTokens()` contract will need to become asynchronous to wait for PIN input.

### References (Compliance)

- [NIAP Mobile Device Fundamentals PP](https://www.niap-ccevs.org/MMO/PP/pp_md_v3.3.pdf)
- [FedRAMP Security Controls](https://www.fedramp.gov/assets/resources/documents/FedRAMP_Security_Controls_Baseline.xlsx)
- [FIPS 140-2 Validated Modules](https://csrc.nist.gov/projects/cryptographic-module-validation-program/validated-modules)
- [Apple Platform Security Guide](https://support.apple.com/guide/security/welcome/web) - Security.framework FIPS status
- [Android Keystore Security](https://source.android.com/docs/security/features/keystore) - StrongBox FIPS status

## References

- [local_auth package](https://pub.dev/packages/local_auth)
- [cryptography package](https://pub.dev/packages/cryptography)
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- [OWASP Mobile Security Guide](https://owasp.org/www-project-mobile-security/)
- [Apple Face ID Guidelines](https://developer.apple.com/design/human-interface-guidelines/face-id)
- [Android BiometricPrompt](https://developer.android.com/reference/android/hardware/biometrics/BiometricPrompt)
