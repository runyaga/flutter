import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:soliplex_client/soliplex_client.dart';
import 'package:soliplex_frontend/features/chat/widgets/steering_input.dart';
import 'package:soliplex_frontend/features/chat/widgets/execution_controls.dart';
import 'package:soliplex_frontend/core/providers/mission_providers.dart';
import 'package:soliplex_frontend/core/services/steering_service.dart';

import '../../helpers/test_helpers.dart';

/// Mock SteeringService for testing.
class MockSteeringService extends Mock implements SteeringService {}

/// Mock MissionControlService for testing.
class MockMissionControlService extends Mock implements MissionControlService {}

void main() {
  group('SteeringInput', () {
    late MockSteeringService mockSteeringService;

    setUp(() {
      mockSteeringService = MockSteeringService();
    });

    group('Visibility', () {
      testWidgets('is visible when mission status is executing', (
        tester,
      ) async {
        // Arrange & Act
        await tester.pumpWidget(
          createTestApp(
            home: const SteeringInput(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              steeringServiceProvider.overrideWithValue(mockSteeringService),
            ],
          ),
        );

        // Assert
        expect(find.byType(SteeringInput), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Agent is working...'), findsOneWidget);
      });

      testWidgets('is hidden when mission status is not executing', (
        tester,
      ) async {
        // Arrange & Act - paused status
        await tester.pumpWidget(
          createTestApp(
            home: const SteeringInput(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.paused,
              ),
              steeringServiceProvider.overrideWithValue(mockSteeringService),
            ],
          ),
        );

        // Assert - should be SizedBox.shrink
        expect(find.byType(TextField), findsNothing);
        expect(find.text('Agent is working...'), findsNothing);
      });

      testWidgets('is hidden when mission status is completed', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(
          createTestApp(
            home: const SteeringInput(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.completed,
              ),
              steeringServiceProvider.overrideWithValue(mockSteeringService),
            ],
          ),
        );

        // Assert
        expect(find.byType(TextField), findsNothing);
      });

      testWidgets('is hidden when mission status is null', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(
          createTestApp(
            home: const SteeringInput(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith((ref) => null),
              steeringServiceProvider.overrideWithValue(mockSteeringService),
            ],
          ),
        );

        // Assert
        expect(find.byType(TextField), findsNothing);
      });
    });

    group('Input Behavior', () {
      testWidgets('shows placeholder text', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(
          createTestApp(
            home: const SteeringInput(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              steeringServiceProvider.overrideWithValue(mockSteeringService),
            ],
          ),
        );

        // Assert
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(
          textField.decoration?.hintText,
          equals('Guide or correct the agent...'),
        );
      });

      testWidgets('allows text entry', (tester) async {
        // Arrange
        await tester.pumpWidget(
          createTestApp(
            home: const SteeringInput(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              steeringServiceProvider.overrideWithValue(mockSteeringService),
            ],
          ),
        );

        // Act
        await tester.enterText(
          find.byType(TextField),
          'Focus on the database first',
        );
        await tester.pump();

        // Assert
        expect(find.text('Focus on the database first'), findsOneWidget);
      });
    });

    group('Send Behavior', () {
      testWidgets('calls steering service when send button tapped', (
        tester,
      ) async {
        // Arrange
        when(
          () => mockSteeringService.sendSteeringToCurrent(
            roomId: any(named: 'roomId'),
            message: any(named: 'message'),
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          createTestApp(
            home: const SteeringInput(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              steeringServiceProvider.overrideWithValue(mockSteeringService),
            ],
          ),
        );

        // Act
        await tester.enterText(find.byType(TextField), 'Test steering');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        // Assert
        verify(
          () => mockSteeringService.sendSteeringToCurrent(
            roomId: 'test-room',
            message: 'Test steering',
          ),
        ).called(1);
      });

      testWidgets('clears input after successful send', (tester) async {
        // Arrange
        when(
          () => mockSteeringService.sendSteeringToCurrent(
            roomId: any(named: 'roomId'),
            message: any(named: 'message'),
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          createTestApp(
            home: const SteeringInput(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              steeringServiceProvider.overrideWithValue(mockSteeringService),
            ],
          ),
        );

        // Act
        await tester.enterText(find.byType(TextField), 'Test steering');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Assert
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, isEmpty);
      });

      testWidgets('does not send empty message', (tester) async {
        // Arrange
        await tester.pumpWidget(
          createTestApp(
            home: const SteeringInput(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              steeringServiceProvider.overrideWithValue(mockSteeringService),
            ],
          ),
        );

        // Act
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        // Assert
        verifyNever(
          () => mockSteeringService.sendSteeringToCurrent(
            roomId: any(named: 'roomId'),
            message: any(named: 'message'),
          ),
        );
      });

      testWidgets('does not send whitespace-only message', (tester) async {
        // Arrange
        await tester.pumpWidget(
          createTestApp(
            home: const SteeringInput(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              steeringServiceProvider.overrideWithValue(mockSteeringService),
            ],
          ),
        );

        // Act
        await tester.enterText(find.byType(TextField), '   ');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        // Assert
        verifyNever(
          () => mockSteeringService.sendSteeringToCurrent(
            roomId: any(named: 'roomId'),
            message: any(named: 'message'),
          ),
        );
      });

      testWidgets('shows loading indicator while sending', (tester) async {
        // Arrange - make the send call slow
        final completer = Completer<void>();
        when(
          () => mockSteeringService.sendSteeringToCurrent(
            roomId: any(named: 'roomId'),
            message: any(named: 'message'),
          ),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(
          createTestApp(
            home: const SteeringInput(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              steeringServiceProvider.overrideWithValue(mockSteeringService),
            ],
          ),
        );

        // Act
        await tester.enterText(find.byType(TextField), 'Test');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        // Assert - should show loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Complete the future
        completer.complete();
        await tester.pumpAndSettle();
      });

      testWidgets('can send by pressing enter', (tester) async {
        // Arrange
        when(
          () => mockSteeringService.sendSteeringToCurrent(
            roomId: any(named: 'roomId'),
            message: any(named: 'message'),
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(
          createTestApp(
            home: const SteeringInput(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              steeringServiceProvider.overrideWithValue(mockSteeringService),
            ],
          ),
        );

        // Act
        await tester.enterText(find.byType(TextField), 'Test steering');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Assert
        verify(
          () => mockSteeringService.sendSteeringToCurrent(
            roomId: 'test-room',
            message: 'Test steering',
          ),
        ).called(1);
      });
    });

    group('Error Handling', () {
      testWidgets('shows snackbar on send failure', (tester) async {
        // Arrange
        when(
          () => mockSteeringService.sendSteeringToCurrent(
            roomId: any(named: 'roomId'),
            message: any(named: 'message'),
          ),
        ).thenThrow(Exception('Network error'));

        await tester.pumpWidget(
          createTestApp(
            home: const SteeringInput(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              steeringServiceProvider.overrideWithValue(mockSteeringService),
            ],
          ),
        );

        // Act
        await tester.enterText(find.byType(TextField), 'Test');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('Failed to send'), findsOneWidget);
      });
    });
  });

  group('ExecutionControls', () {
    late MockMissionControlService mockControlService;

    setUp(() {
      mockControlService = MockMissionControlService();
    });

    group('Visibility', () {
      testWidgets('shows controls when executing', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(
          createTestApp(
            home: const ExecutionControls(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              missionControlServiceProvider.overrideWithValue(
                mockControlService,
              ),
            ],
          ),
        );

        // Assert
        expect(find.byIcon(Icons.pause), findsOneWidget);
        expect(find.byIcon(Icons.stop), findsOneWidget);
      });

      testWidgets('shows play button when paused', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(
          createTestApp(
            home: const ExecutionControls(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.paused,
              ),
              missionControlServiceProvider.overrideWithValue(
                mockControlService,
              ),
            ],
          ),
        );

        // Assert
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.byIcon(Icons.stop), findsOneWidget);
      });

      testWidgets('is hidden when completed', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(
          createTestApp(
            home: const ExecutionControls(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.completed,
              ),
              missionControlServiceProvider.overrideWithValue(
                mockControlService,
              ),
            ],
          ),
        );

        // Assert
        expect(find.byIcon(Icons.pause), findsNothing);
        expect(find.byIcon(Icons.play_arrow), findsNothing);
        expect(find.byIcon(Icons.stop), findsNothing);
      });

      testWidgets('is hidden when null status', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(
          createTestApp(
            home: const ExecutionControls(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith((ref) => null),
              missionControlServiceProvider.overrideWithValue(
                mockControlService,
              ),
            ],
          ),
        );

        // Assert
        expect(find.byIcon(Icons.pause), findsNothing);
        expect(find.byIcon(Icons.stop), findsNothing);
      });
    });

    group('Pause/Resume', () {
      testWidgets('calls pause when pause button tapped', (tester) async {
        // Arrange
        when(() => mockControlService.pause(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          createTestApp(
            home: const ExecutionControls(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              missionControlServiceProvider.overrideWithValue(
                mockControlService,
              ),
            ],
          ),
        );

        // Act
        await tester.tap(find.byIcon(Icons.pause));
        await tester.pump();

        // Assert
        verify(() => mockControlService.pause('test-room')).called(1);
      });

      testWidgets('calls resume when play button tapped', (tester) async {
        // Arrange
        when(() => mockControlService.resume(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          createTestApp(
            home: const ExecutionControls(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.paused,
              ),
              missionControlServiceProvider.overrideWithValue(
                mockControlService,
              ),
            ],
          ),
        );

        // Act
        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pump();

        // Assert
        verify(() => mockControlService.resume('test-room')).called(1);
      });
    });

    group('Cancel', () {
      testWidgets('shows confirmation dialog when cancel tapped', (
        tester,
      ) async {
        // Arrange
        await tester.pumpWidget(
          createTestApp(
            home: const ExecutionControls(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              missionControlServiceProvider.overrideWithValue(
                mockControlService,
              ),
            ],
          ),
        );

        // Act
        await tester.tap(find.byIcon(Icons.stop));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Cancel Mission?'), findsOneWidget);
        expect(
          find.text(
            'This will stop the agent immediately. Any in-progress work may be lost.',
          ),
          findsOneWidget,
        );
        expect(find.text('Keep Running'), findsOneWidget);
        expect(find.text('Cancel Mission'), findsOneWidget);
      });

      testWidgets('calls cancel when confirmed', (tester) async {
        // Arrange
        when(() => mockControlService.cancel(any())).thenAnswer((_) async {});

        await tester.pumpWidget(
          createTestApp(
            home: const ExecutionControls(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              missionControlServiceProvider.overrideWithValue(
                mockControlService,
              ),
            ],
          ),
        );

        // Act
        await tester.tap(find.byIcon(Icons.stop));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel Mission'));
        await tester.pumpAndSettle();

        // Assert
        verify(() => mockControlService.cancel('test-room')).called(1);
      });

      testWidgets('does not call cancel when dismissed', (tester) async {
        // Arrange
        await tester.pumpWidget(
          createTestApp(
            home: const ExecutionControls(roomId: 'test-room'),
            overrides: [
              missionStatusProvider('test-room').overrideWith(
                (ref) => MissionStatus.executing,
              ),
              missionControlServiceProvider.overrideWithValue(
                mockControlService,
              ),
            ],
          ),
        );

        // Act
        await tester.tap(find.byIcon(Icons.stop));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keep Running'));
        await tester.pumpAndSettle();

        // Assert
        verifyNever(() => mockControlService.cancel(any()));
      });
    });
  });
}

