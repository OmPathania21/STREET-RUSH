class GameBalanceConfig {
  const GameBalanceConfig({
    this.baseEnemySpawnInterval = 1.5,
    this.minEnemySpawnInterval = 0.58,
    this.coinSpawnInterval = 2.5,
    this.distancePerSecond = 26,
    this.maxTrafficSpeedMultiplier = 2.1,
    this.maxBackgroundSpeedMultiplier = 1.9,
    this.difficultyRampDistance = 4200,
    this.rewardedCoinBonus = 30,
    this.interstitialEveryNGameOvers = 3,
    this.newRecordBonusCoins = 20,
    this.shareChallengeOffsetDistance = 120,
    this.reviewMinSessions = 3,
    this.reviewDistanceThreshold = 1400,
    this.reviewPromptCooldownDays = 7,
    this.maxReviewPrompts = 3,
  });

  final double baseEnemySpawnInterval;
  final double minEnemySpawnInterval;
  final double coinSpawnInterval;
  final double distancePerSecond;
  final double maxTrafficSpeedMultiplier;
  final double maxBackgroundSpeedMultiplier;
  final double difficultyRampDistance;

  final int rewardedCoinBonus;
  final int interstitialEveryNGameOvers;
  final int newRecordBonusCoins;
  final int shareChallengeOffsetDistance;
  final int reviewMinSessions;
  final int reviewDistanceThreshold;
  final int reviewPromptCooldownDays;
  final int maxReviewPrompts;
}
