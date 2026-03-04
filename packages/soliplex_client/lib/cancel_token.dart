/// Public export of `CancelToken` for cross-package use.
///
/// The main barrel (`soliplex_client.dart`) hides `CancelToken` to avoid
/// collision with `ag_ui`'s identically-named class. Import this file
/// directly when you need the Soliplex-specific `CancelToken`.
library;

export 'src/utils/cancel_token.dart';
