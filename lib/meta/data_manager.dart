import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataManager {
  DataManager._(this._prefs) {
    _loadFromPrefs();
  }

  // Core offline progression keys.
  static const String _totalCoinsKey = 'meta_total_coins';
  static const String _highScoreKey = 'meta_high_score';
  static const String _handlingLevelKey = 'meta_handling_level';
  static const String _coinMagnetLevelKey = 'meta_coin_magnet_level';

  // Additional local-only meta keys used by growth/liveops features.
  static const String _removeAdsKey = 'meta_remove_ads';
  static const String _sessionCountKey = 'meta_session_count';
  static const String _dailyStreakKey = 'meta_daily_streak';
  static const String _lastDailyRewardEpochDayKey =
      'meta_last_daily_reward_epoch_day';
  static const String _lastRunDistanceKey = 'meta_last_run_distance';
  static const String _reviewPromptCountKey = 'meta_review_prompt_count';
  static const String _lastReviewPromptEpochDayKey =
      'meta_last_review_prompt_epoch_day';

  static DataManager? _instance;

  final SharedPreferences _prefs;
  Future<void> _pendingWrite = Future<void>.value();

  final ValueNotifier<int> totalCoinsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> highScoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> handlingLevelNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> coinMagnetLevelNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> removeAdsNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> sessionCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> dailyStreakNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> lastDailyRewardEpochDayNotifier =
      ValueNotifier<int>(0);
  final ValueNotifier<int> lastRunDistanceNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> reviewPromptCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> lastReviewPromptEpochDayNotifier =
      ValueNotifier<int>(0);

  int get totalCoins => totalCoinsNotifier.value;
  int get highScore => highScoreNotifier.value;
  int get handlingLevel => handlingLevelNotifier.value;
  int get coinMagnetLevel => coinMagnetLevelNotifier.value;
  bool get removeAdsPurchased => removeAdsNotifier.value;
  int get sessionCount => sessionCountNotifier.value;
  int get dailyStreak => dailyStreakNotifier.value;
  int get lastDailyRewardEpochDay => lastDailyRewardEpochDayNotifier.value;
  int get lastRunDistance => lastRunDistanceNotifier.value;
  int get reviewPromptCount => reviewPromptCountNotifier.value;
  int get lastReviewPromptEpochDay => lastReviewPromptEpochDayNotifier.value;

  static Future<DataManager> getInstance() async {
    if (_instance != null) {
      return _instance!;
    }

    final prefs = await SharedPreferences.getInstance();
    _instance = DataManager._(prefs);
    return _instance!;
  }

  void _loadFromPrefs() {
    totalCoinsNotifier.value = _safeReadInt(_totalCoinsKey);
    highScoreNotifier.value = _safeReadInt(_highScoreKey);
    handlingLevelNotifier.value = _safeReadInt(_handlingLevelKey);
    coinMagnetLevelNotifier.value = _safeReadInt(_coinMagnetLevelKey);
    removeAdsNotifier.value = _safeReadBool(_removeAdsKey);
    sessionCountNotifier.value = _safeReadInt(_sessionCountKey);
    dailyStreakNotifier.value = _safeReadInt(_dailyStreakKey);
    lastDailyRewardEpochDayNotifier.value =
        _safeReadInt(_lastDailyRewardEpochDayKey);
    lastRunDistanceNotifier.value = _safeReadInt(_lastRunDistanceKey);
    reviewPromptCountNotifier.value = _safeReadInt(_reviewPromptCountKey);
    lastReviewPromptEpochDayNotifier.value =
        _safeReadInt(_lastReviewPromptEpochDayKey);
  }

  int _safeReadInt(String key) {
    try {
      return _prefs.getInt(key) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  bool _safeReadBool(String key) {
    try {
      return _prefs.getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _queueWrite(Future<void> Function() writeTask) {
    _pendingWrite = _pendingWrite.then((_) => writeTask()).catchError((_) {});
    return _pendingWrite;
  }

  Future<void> _writeInt(String key, int value) {
    return _queueWrite(() async {
      try {
        if (_prefs.getInt(key) == value) {
          return;
        }
        await _prefs.setInt(key, value);
      } catch (_) {
        // Keep in-memory values even if a disk write fails unexpectedly.
      }
    });
  }

  Future<void> _writeBool(String key, bool value) {
    return _queueWrite(() async {
      try {
        if (_prefs.getBool(key) == value) {
          return;
        }
        await _prefs.setBool(key, value);
      } catch (_) {
        // Keep in-memory values even if a disk write fails unexpectedly.
      }
    });
  }

  Future<void> flushPendingWrites() {
    return _pendingWrite;
  }

  Future<void> addCoins(int amount) async {
    if (amount <= 0) {
      return;
    }
    totalCoinsNotifier.value += amount;
    await _writeInt(_totalCoinsKey, totalCoinsNotifier.value);
  }

  Future<bool> spendCoins(int amount) async {
    if (amount <= 0) {
      return true;
    }

    if (totalCoinsNotifier.value < amount) {
      return false;
    }

    totalCoinsNotifier.value -= amount;
    await _writeInt(_totalCoinsKey, totalCoinsNotifier.value);
    return true;
  }

  Future<void> updateHighScoreIfBetter(int candidateScore) async {
    if (candidateScore <= highScoreNotifier.value) {
      return;
    }

    highScoreNotifier.value = candidateScore;
    await _writeInt(_highScoreKey, highScoreNotifier.value);
  }

  Future<void> setHandlingLevel(int level) async {
    final int normalized = level < 0 ? 0 : level;
    if (handlingLevelNotifier.value == normalized) {
      return;
    }
    handlingLevelNotifier.value = normalized;
    await _writeInt(_handlingLevelKey, normalized);
  }

  Future<void> setCoinMagnetLevel(int level) async {
    final int normalized = level < 0 ? 0 : level;
    if (coinMagnetLevelNotifier.value == normalized) {
      return;
    }
    coinMagnetLevelNotifier.value = normalized;
    await _writeInt(_coinMagnetLevelKey, normalized);
  }

  Future<void> setRemoveAdsPurchased(bool value) async {
    if (removeAdsNotifier.value == value) {
      return;
    }
    removeAdsNotifier.value = value;
    await _writeBool(_removeAdsKey, value);
  }

  Future<int> incrementSessionCount() async {
    sessionCountNotifier.value += 1;
    await _writeInt(_sessionCountKey, sessionCountNotifier.value);
    return sessionCountNotifier.value;
  }

  Future<void> setDailyStreak(int value) async {
    final int normalized = value < 0 ? 0 : value;
    if (dailyStreakNotifier.value == normalized) {
      return;
    }
    dailyStreakNotifier.value = normalized;
    await _writeInt(_dailyStreakKey, normalized);
  }

  Future<void> setLastDailyRewardEpochDay(int epochDay) async {
    final int normalized = epochDay < 0 ? 0 : epochDay;
    if (lastDailyRewardEpochDayNotifier.value == normalized) {
      return;
    }
    lastDailyRewardEpochDayNotifier.value = normalized;
    await _writeInt(_lastDailyRewardEpochDayKey, normalized);
  }

  Future<void> setLastRunDistance(int value) async {
    final int normalized = value < 0 ? 0 : value;
    if (lastRunDistanceNotifier.value == normalized) {
      return;
    }
    lastRunDistanceNotifier.value = normalized;
    await _writeInt(_lastRunDistanceKey, normalized);
  }

  Future<int> incrementReviewPromptCount() async {
    reviewPromptCountNotifier.value += 1;
    await _writeInt(_reviewPromptCountKey, reviewPromptCountNotifier.value);
    return reviewPromptCountNotifier.value;
  }

  Future<void> setLastReviewPromptEpochDay(int epochDay) async {
    final int normalized = epochDay < 0 ? 0 : epochDay;
    if (lastReviewPromptEpochDayNotifier.value == normalized) {
      return;
    }
    lastReviewPromptEpochDayNotifier.value = normalized;
    await _writeInt(_lastReviewPromptEpochDayKey, normalized);
  }

  void dispose() {
    totalCoinsNotifier.dispose();
    highScoreNotifier.dispose();
    handlingLevelNotifier.dispose();
    coinMagnetLevelNotifier.dispose();
    removeAdsNotifier.dispose();
    sessionCountNotifier.dispose();
    dailyStreakNotifier.dispose();
    lastDailyRewardEpochDayNotifier.dispose();
    lastRunDistanceNotifier.dispose();
    reviewPromptCountNotifier.dispose();
    lastReviewPromptEpochDayNotifier.dispose();
  }
}