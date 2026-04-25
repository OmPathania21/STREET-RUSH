import '../meta/data_manager.dart';

class DailyRewardResult {
  const DailyRewardResult({
    required this.granted,
    required this.rewardCoins,
    required this.streak,
  });

  final bool granted;
  final int rewardCoins;
  final int streak;
}

class RetentionManager {
  RetentionManager({
    required this.dataManager,
    this.baseDailyReward = 25,
    this.maxDailyReward = 75,
  });

  final DataManager dataManager;
  final int baseDailyReward;
  final int maxDailyReward;

  int _todayEpochDayUtc() {
    final now = DateTime.now().toUtc();
    final midnight = DateTime.utc(now.year, now.month, now.day);
    return midnight.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  Future<int> trackSessionStart() {
    return dataManager.incrementSessionCount();
  }

  Future<DailyRewardResult> claimDailyRewardIfAvailable() async {
    final int today = _todayEpochDayUtc();
    final int lastClaimDay = dataManager.lastDailyRewardEpochDay;

    if (lastClaimDay == today) {
      return DailyRewardResult(
        granted: false,
        rewardCoins: 0,
        streak: dataManager.dailyStreak,
      );
    }

    int nextStreak = 1;
    if (lastClaimDay > 0 && (today - lastClaimDay) == 1) {
      nextStreak = dataManager.dailyStreak + 1;
    }

    final int reward = (baseDailyReward + ((nextStreak - 1) * 5))
        .clamp(baseDailyReward, maxDailyReward)
        .toInt();

    await dataManager.setDailyStreak(nextStreak);
    await dataManager.setLastDailyRewardEpochDay(today);
    await dataManager.addCoins(reward);

    return DailyRewardResult(
      granted: true,
      rewardCoins: reward,
      streak: nextStreak,
    );
  }
}
