import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsManager {
  AnalyticsManager(this._analytics);

  final FirebaseAnalytics? _analytics;

  Future<void> _logEvent({
    required String name,
    Map<String, Object?>? parameters,
  }) async {
    final analytics = _analytics;
    if (analytics == null) {
      return;
    }
    try {
      await analytics.logEvent(name: name, parameters: parameters);
    } catch (_) {
      // Analytics errors should never affect game runtime.
    }
  }

  Future<void> trackSessionStart({required int sessionCount}) {
    return _logEvent(
      name: 'session_start',
      parameters: {
        'session_count': sessionCount,
      },
    );
  }

  Future<void> trackGameStart() {
    return _logEvent(name: 'game_start');
  }

  Future<void> trackGameOver({
    required int distance,
    required int runCoins,
    required bool revived,
  }) {
    return _logEvent(
      name: 'game_over',
      parameters: {
        'distance': distance,
        'run_coins': runCoins,
        'used_revive': revived,
      },
    );
  }

  Future<void> trackDistanceReached({required int distance}) {
    return _logEvent(
      name: 'distance_reached',
      parameters: {
        'distance': distance,
      },
    );
  }

  Future<void> trackCoinsCollected({required int totalRunCoins}) {
    return _logEvent(
      name: 'coins_collected',
      parameters: {
        'run_coins': totalRunCoins,
      },
    );
  }

  Future<void> trackUpgradePurchase({
    required String upgrade,
    required int level,
    required int cost,
  }) {
    return _logEvent(
      name: 'upgrade_purchase',
      parameters: {
        'upgrade': upgrade,
        'level': level,
        'cost': cost,
      },
    );
  }

  Future<void> trackAdWatched({
    required String adType,
    required String placement,
    int? reward,
  }) {
    return _logEvent(
      name: 'ad_watched',
      parameters: {
        'ad_type': adType,
        'placement': placement,
        if (reward != null) 'reward': reward,
      },
    );
  }

  Future<void> trackDailyReward({
    required int reward,
    required int streak,
  }) {
    return _logEvent(
      name: 'daily_reward_claimed',
      parameters: {
        'reward': reward,
        'streak': streak,
      },
    );
  }

  Future<void> trackPurchase({
    required String productId,
    required String purchaseType,
  }) {
    return _logEvent(
      name: 'iap_purchase',
      parameters: {
        'product_id': productId,
        'type': purchaseType,
      },
    );
  }

  Future<void> trackReviveUsed() {
    return _logEvent(name: 'revive_used');
  }

  Future<void> trackShareChallenge({
    required int distance,
    required int challengeDistance,
    required String referralCode,
  }) {
    return _logEvent(
      name: 'share_challenge',
      parameters: {
        'distance': distance,
        'challenge_distance': challengeDistance,
        'referral_code': referralCode,
      },
    );
  }

  Future<void> trackReviewPromptShown({required String trigger}) {
    return _logEvent(
      name: 'review_prompt_shown',
      parameters: {
        'trigger': trigger,
      },
    );
  }
}
