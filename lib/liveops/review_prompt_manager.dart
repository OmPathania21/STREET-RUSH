import 'package:in_app_review/in_app_review.dart';

import '../meta/data_manager.dart';
import 'analytics_manager.dart';

class ReviewPromptManager {
  ReviewPromptManager({
    required this.dataManager,
    required this.analyticsManager,
    this.minSessionsBeforePrompt = 3,
    this.minDistanceForPrompt = 1400,
    this.promptCooldownDays = 7,
    this.maxLifetimePrompts = 3,
    InAppReview? inAppReview,
  }) : _inAppReview = inAppReview ?? InAppReview.instance;

  final DataManager dataManager;
  final AnalyticsManager analyticsManager;
  final int minSessionsBeforePrompt;
  final int minDistanceForPrompt;
  final int promptCooldownDays;
  final int maxLifetimePrompts;
  final InAppReview _inAppReview;

  int _todayEpochDayUtc() {
    final now = DateTime.now().toUtc();
    final midnight = DateTime.utc(now.year, now.month, now.day);
    return midnight.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  Future<void> maybePromptAfterPositiveRun({
    required int distance,
    required bool newRecord,
    required bool missionCompleted,
  }) async {
    final bool positiveMoment =
        newRecord || missionCompleted || distance >= minDistanceForPrompt;
    if (!positiveMoment) {
      return;
    }

    if (dataManager.sessionCount < minSessionsBeforePrompt) {
      return;
    }

    if (dataManager.reviewPromptCount >= maxLifetimePrompts) {
      return;
    }

    final int today = _todayEpochDayUtc();
    final int lastPromptDay = dataManager.lastReviewPromptEpochDay;
    if (lastPromptDay > 0 && (today - lastPromptDay) < promptCooldownDays) {
      return;
    }

    bool isAvailable = false;
    try {
      isAvailable = await _inAppReview.isAvailable();
    } catch (_) {
      return;
    }

    if (!isAvailable) {
      return;
    }

    try {
      await _inAppReview.requestReview();
      await dataManager.incrementReviewPromptCount();
      await dataManager.setLastReviewPromptEpochDay(today);

      final String trigger = newRecord
          ? 'new_record'
          : (missionCompleted ? 'mission_complete' : 'great_run');
      await analyticsManager.trackReviewPromptShown(trigger: trigger);
    } catch (_) {
      // Never block core gameplay on review prompt flow.
    }
  }
}
