import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum MissionType {
  collectCoins,
  reachDistance,
}

class Mission {
  const Mission({
    required this.type,
    required this.target,
    required this.reward,
  });

  final MissionType type;
  final int target;
  final int reward;

  String get title {
    switch (type) {
      case MissionType.collectCoins:
        return 'Collect $target coins in one run';
      case MissionType.reachDistance:
        return 'Reach $target distance in one run';
    }
  }

  String get progressUnit {
    switch (type) {
      case MissionType.collectCoins:
        return 'coins';
      case MissionType.reachDistance:
        return 'm';
    }
  }
}

class MissionCompletion {
  const MissionCompletion({
    required this.completedMission,
  });

  final Mission completedMission;
}

class MissionSystem {
  MissionSystem({math.Random? random}) : _random = random ?? math.Random() {
    _currentMission = _generateMission();
    missionNotifier.value = _currentMission;
  }

  final math.Random _random;
  late Mission _currentMission;
  bool _completedInRun = false;

  final ValueNotifier<Mission?> missionNotifier = ValueNotifier<Mission?>(null);
  final ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);

  Mission get currentMission => _currentMission;
  int get progress => progressNotifier.value;
  bool get isCompletedInRun => _completedInRun;

  void beginRun() {
    progressNotifier.value = 0;
    _completedInRun = false;
  }

  MissionCompletion? updateCoinsProgress(int coinsCollectedInRun) {
    if (_completedInRun || _currentMission.type != MissionType.collectCoins) {
      return null;
    }

    return _applyProgress(coinsCollectedInRun);
  }

  MissionCompletion? updateDistanceProgress(int distanceInRun) {
    if (_completedInRun || _currentMission.type != MissionType.reachDistance) {
      return null;
    }

    return _applyProgress(distanceInRun);
  }

  MissionCompletion? _applyProgress(int rawProgress) {
    final int normalized = rawProgress < 0 ? 0 : rawProgress;
    final int clamped = normalized > _currentMission.target
        ? _currentMission.target
        : normalized;
    if (progressNotifier.value != clamped) {
      progressNotifier.value = clamped;
    }

    if (clamped < _currentMission.target) {
      return null;
    }

    _completedInRun = true;
    final completed = _currentMission;

    // Immediately queue a fresh mission for the next run loop.
    _currentMission = _generateMission();
    progressNotifier.value = 0;
    missionNotifier.value = _currentMission;

    return MissionCompletion(completedMission: completed);
  }

  Mission _generateMission() {
    final bool coinMission = _random.nextBool();
    if (coinMission) {
      final int target = 12 + (_random.nextInt(4) * 4);
      final int reward = 35 + (target * 3);
      return Mission(
        type: MissionType.collectCoins,
        target: target,
        reward: reward,
      );
    }

    final int target = 700 + (_random.nextInt(5) * 200);
    final int reward = 55 + (target ~/ 20);
    return Mission(
      type: MissionType.reachDistance,
      target: target,
      reward: reward,
    );
  }

  void dispose() {
    missionNotifier.dispose();
    progressNotifier.dispose();
  }
}