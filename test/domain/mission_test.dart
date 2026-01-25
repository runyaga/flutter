import 'package:flutter_test/flutter_test.dart';
import 'package:soliplex_client/src/domain/mission.dart';
import 'package:soliplex_client/src/generated/mission_state.dart' as gen;

void main() {
  group('MissionStatus', () {
    test('fromString parses snake_case correctly', () {
      expect(MissionStatus.fromString('planning'), MissionStatus.planning);
      expect(MissionStatus.fromString('executing'), MissionStatus.executing);
      expect(MissionStatus.fromString('awaiting_approval'),
          MissionStatus.awaitingApproval);
      expect(MissionStatus.fromString('paused'), MissionStatus.paused);
      expect(MissionStatus.fromString('completed'), MissionStatus.completed);
      expect(MissionStatus.fromString('failed'), MissionStatus.failed);
    });

    test('fromString handles camelCase', () {
      expect(MissionStatus.fromString('awaitingApproval'),
          MissionStatus.awaitingApproval);
    });

    test('fromString defaults to planning for unknown values', () {
      expect(MissionStatus.fromString('unknown'), MissionStatus.planning);
      expect(MissionStatus.fromString(''), MissionStatus.planning);
    });
  });

  group('Mission', () {
    late gen.MissionState dto;
    late Mission mission;

    setUp(() {
      dto = gen.MissionState(
        artifacts: [],
        createdAt: DateTime(2024, 1, 1),
        goal: 'Test goal',
        missionId: 'mission-123',
        pendingApprovals: [],
        progressPct: 50,
        status: 'executing',
        tasks: [],
        threadId: 'thread-456',
        updatedAt: DateTime(2024, 1, 2),
      );
      mission = Mission(dto);
    });

    test('exposes DTO fields correctly', () {
      expect(mission.id, 'mission-123');
      expect(mission.threadId, 'thread-456');
      expect(mission.goal, 'Test goal');
      expect(mission.progressPct, 50);
      expect(mission.createdAt, DateTime(2024, 1, 1));
      expect(mission.updatedAt, DateTime(2024, 1, 2));
    });

    test('parses status to enum', () {
      expect(mission.status, MissionStatus.executing);
    });

    test('isActive returns true when executing', () {
      expect(mission.isActive, isTrue);
    });

    test('isActive returns false when not executing', () {
      final completedDto = gen.MissionState(
        artifacts: [],
        createdAt: DateTime.now(),
        goal: 'Test',
        missionId: 'mission-1',
        pendingApprovals: [],
        progressPct: 100,
        status: 'completed',
        tasks: [],
        threadId: 'thread-1',
        updatedAt: DateTime.now(),
      );
      expect(Mission(completedDto).isActive, isFalse);
    });

    test('needsApproval returns true when awaiting_approval', () {
      final awaitingDto = gen.MissionState(
        artifacts: [],
        createdAt: DateTime.now(),
        goal: 'Test',
        missionId: 'mission-1',
        pendingApprovals: [],
        progressPct: 50,
        status: 'awaiting_approval',
        tasks: [],
        threadId: 'thread-1',
        updatedAt: DateTime.now(),
      );
      expect(Mission(awaitingDto).needsApproval, isTrue);
    });

    test('isComplete returns true for completed status', () {
      final completedDto = gen.MissionState(
        artifacts: [],
        createdAt: DateTime.now(),
        goal: 'Test',
        missionId: 'mission-1',
        pendingApprovals: [],
        progressPct: 100,
        status: 'completed',
        tasks: [],
        threadId: 'thread-1',
        updatedAt: DateTime.now(),
      );
      expect(Mission(completedDto).isComplete, isTrue);
    });

    test('isComplete returns true for failed status', () {
      final failedDto = gen.MissionState(
        artifacts: [],
        createdAt: DateTime.now(),
        goal: 'Test',
        missionId: 'mission-1',
        pendingApprovals: [],
        progressPct: 50,
        status: 'failed',
        tasks: [],
        threadId: 'thread-1',
        updatedAt: DateTime.now(),
      );
      expect(Mission(failedDto).isComplete, isTrue);
    });

    test('isComplete returns false for in-progress statuses', () {
      expect(mission.isComplete, isFalse);
    });

    test('isPaused returns true for paused status', () {
      final pausedDto = gen.MissionState(
        artifacts: [],
        createdAt: DateTime.now(),
        goal: 'Test',
        missionId: 'mission-1',
        pendingApprovals: [],
        progressPct: 50,
        status: 'paused',
        tasks: [],
        threadId: 'thread-1',
        updatedAt: DateTime.now(),
      );
      expect(Mission(pausedDto).isPaused, isTrue);
    });

    test('isPlanning returns true for planning status', () {
      final planningDto = gen.MissionState(
        artifacts: [],
        createdAt: DateTime.now(),
        goal: 'Test',
        missionId: 'mission-1',
        pendingApprovals: [],
        progressPct: 0,
        status: 'planning',
        tasks: [],
        threadId: 'thread-1',
        updatedAt: DateTime.now(),
      );
      expect(Mission(planningDto).isPlanning, isTrue);
    });

    test('taskCount returns number of tasks', () {
      expect(mission.taskCount, 0);
    });

    test('artifactCount returns number of artifacts', () {
      expect(mission.artifactCount, 0);
    });

    test('pendingApprovalCount returns number of pending approvals', () {
      expect(mission.pendingApprovalCount, 0);
    });

    test('fromJson factory creates mission from map', () {
      final json = {
        'mission_id': 'mission-789',
        'thread_id': 'thread-123',
        'goal': 'JSON goal',
        'status': 'planning',
        'progress_pct': 25,
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-02T00:00:00.000Z',
        'tasks': <Map<String, dynamic>>[],
        'artifacts': <Map<String, dynamic>>[],
        'pending_approvals': <Map<String, dynamic>>[],
      };
      final fromJson = Mission.fromJson(json);
      expect(fromJson.id, 'mission-789');
      expect(fromJson.goal, 'JSON goal');
      expect(fromJson.status, MissionStatus.planning);
    });

    test('equality is based on id', () {
      final mission2 = Mission(dto);
      expect(mission == mission2, isTrue);
    });

    test('toString includes key fields', () {
      final str = mission.toString();
      expect(str, contains('mission-123'));
      expect(str, contains('executing'));
      expect(str, contains('Test goal'));
    });
  });
}
