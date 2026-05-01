import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/parallax.dart';
import 'package:flutter/material.dart';

import '../meta/data_manager.dart';
import '../meta/mission_system.dart';
import '../meta/upgrade_system.dart';
import '../liveops/ads_manager.dart';
import '../liveops/analytics_manager.dart';
import '../liveops/game_balance_config.dart';
import '../liveops/purchase_manager.dart';
import '../liveops/review_prompt_manager.dart';
import '../liveops/retention_manager.dart';
import '../liveops/share_manager.dart';
import 'audio_manager.dart';
import 'coin.dart';
import 'enemy_car.dart';
import 'feedback_effects.dart';
import 'player_car.dart';

enum StreetRushState {
  menu,
  garage,
  playing,
  gameOver,
}

class StreetRushGame extends FlameGame with HasCollisionDetection {
  StreetRushGame({
    required this.dataManager,
    required this.upgradeSystem,
    required this.missionSystem,
    required this.adsManager,
    required this.analyticsManager,
    required this.purchaseManager,
    required this.retentionManager,
    required this.shareManager,
    required this.reviewPromptManager,
    this.balanceConfig = const GameBalanceConfig(),
  });

  static const String hudOverlay = 'HudOverlay';
  static const String menuOverlay = 'MainMenuOverlay';
  static const String garageOverlay = 'GarageOverlay';
  static const String gameOverOverlay = 'GameOverOverlay';

  static const String _playerSpriteAsset = 'player_car.png';
  static const String _enemySpriteAsset = 'enemy_car.png';
  static const String _coinSpriteAsset = 'coin.png';
  static const String _roadBaseAsset = 'road_base.png';
  static const String _roadMarkingsAsset = 'road_markings.png';

  final DataManager dataManager;
  final UpgradeSystem upgradeSystem;
  final MissionSystem missionSystem;
  final AdsManager adsManager;
  final AnalyticsManager analyticsManager;
  final PurchaseManager purchaseManager;
  final RetentionManager retentionManager;
  final GrowthShareManager shareManager;
  final ReviewPromptManager reviewPromptManager;
  final GameBalanceConfig balanceConfig;

  double get baseEnemySpawnInterval => balanceConfig.baseEnemySpawnInterval;
  double get minEnemySpawnInterval => balanceConfig.minEnemySpawnInterval;
  double get coinSpawnInterval => balanceConfig.coinSpawnInterval;
  double get distancePerSecond => balanceConfig.distancePerSecond;
  double get maxTrafficSpeedMultiplier => balanceConfig.maxTrafficSpeedMultiplier;
  double get maxBackgroundSpeedMultiplier =>
      balanceConfig.maxBackgroundSpeedMultiplier;
  double get difficultyRampDistance => balanceConfig.difficultyRampDistance;

  late final PlayerCar playerCar;
  late final _DragInputLayer _dragInputLayer;
  late final ParallaxComponent _roadParallax;

  late final Sprite _playerSprite;
  late final Sprite _enemySprite;
  late final Sprite _coinSprite;

  final math.Random _random = math.Random();
  final GameAudioManager _audio = GameAudioManager();

  final ValueNotifier<int> distanceScoreNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> coinCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String?> missionFeedbackNotifier =
      ValueNotifier<String?>(null);

  StreetRushState _state = StreetRushState.menu;
  double _enemySpawnAccumulator = 0;
  double _coinSpawnAccumulator = 0;
  double _distanceProgress = 0;
  double _missionFeedbackTimeLeft = 0;

  double _baseTrafficSpeed = 0;
  double _baseBackgroundSpeed = 0;
  double _currentTrafficSpeed = 0;
  double _currentBackgroundSpeed = 0;
  double _currentEnemySpawnInterval = 1.5;

  int _distanceScore = 0;
  int _coinCount = 0;
  bool _resumeEngineAfterLifecycle = false;
  bool _reviveUsedThisRun = false;
  bool _missionCompletedThisRun = false;
  bool _newRecordThisRun = false;
  bool _newRecordBonusGranted = false;
  int _persistedRunCoins = 0;
  int _persistedRunDistance = 0;
  int _distanceDeltaVsLastRun = 0;
  int _challengeTargetDistance = 0;
  int _lastDistanceEventMilestone = 0;
  int _lastCoinEventMilestone = 0;

  StreetRushState get state => _state;
  int get distanceScore => _distanceScore;
  int get coinCount => _coinCount;
  bool get canUseReviveAd => !_reviveUsedThisRun;
  bool get canShowRewardedAd => adsManager.hasRewardedReady;
  bool get isRemoveAdsPurchased => purchaseManager.isRemoveAdsPurchased;
  bool get isIapAvailable => purchaseManager.isAvailable;
  bool get isNewRecordThisRun => _newRecordThisRun;
  int get distanceDeltaVsLastRun => _distanceDeltaVsLastRun;
  int get challengeTargetDistance => _challengeTargetDistance;
  String get shareReferralCode => shareManager.referralCodeForPlayer(
        highScore: dataManager.highScore,
        sessionCount: dataManager.sessionCount,
      );

  int get bankCoins => dataManager.totalCoins;
  int get highScore => dataManager.highScore;

  int get handlingLevel => upgradeSystem.levelFor(UpgradeType.handling);
  int get coinMagnetLevel => upgradeSystem.levelFor(UpgradeType.coinMagnet);

  int get handlingUpgradeCost =>
      upgradeSystem.costForNextLevel(UpgradeType.handling);
  int get coinMagnetUpgradeCost =>
      upgradeSystem.costForNextLevel(UpgradeType.coinMagnet);

  bool get isHandlingMax => upgradeSystem.isMaxLevel(UpgradeType.handling);
  bool get isCoinMagnetMax =>
      upgradeSystem.isMaxLevel(UpgradeType.coinMagnet);

  Mission get currentMission => missionSystem.currentMission;
  int get missionProgress => missionSystem.progress;

  Listenable get garageListenable => Listenable.merge(
        [
          dataManager.totalCoinsNotifier,
          dataManager.handlingLevelNotifier,
          dataManager.coinMagnetLevelNotifier,
        ],
      );

  @override
  Color backgroundColor() => const Color(0xFF0E1218);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      // Try to load images, but continue without them if they fail
      try {
        await images.loadAll([
          _playerSpriteAsset,
          _enemySpriteAsset,
          _coinSpriteAsset,
          _roadBaseAsset,
          _roadMarkingsAsset,
        ]);

        _playerSprite = Sprite(images.fromCache(_playerSpriteAsset));
        _enemySprite = Sprite(images.fromCache(_enemySpriteAsset));
        _coinSprite = Sprite(images.fromCache(_coinSpriteAsset));
      } catch (e) {
        print('Warning: Failed to load images: $e');
        print('Game will continue with placeholder rendering');
        // Create minimal valid sprites or skip sprite loading
        // Game entities will render as colored rectangles instead
      }

      // Skip parallax background if it fails to load
      try {
        _roadParallax = await loadParallaxComponent(
          [
            ParallaxImageData(_roadBaseAsset),
            ParallaxImageData(_roadMarkingsAsset),
          ],
          baseVelocity: Vector2(0, 220),
          velocityMultiplierDelta: Vector2(1.0, 1.08),
          repeat: ImageRepeat.repeat,
          fill: LayerFill.width,
          alignment: Alignment.topCenter,
        )
          ..priority = -200;

        await add(_roadParallax);
      } catch (e) {
        print('Warning: Failed to load parallax: $e');
      }

      playerCar = PlayerCar(
        sprite: _playerSprite,
        onHitEnemy: triggerGameOver,
        onCollectCoin: collectCoin,
      );
      _dragInputLayer = _DragInputLayer();

      await add(playerCar);
      await add(_dragInputLayer);

      _layoutForCurrentSize(size);
      _applyUpgradesToPlayer();
      playerCar.setTargetX(size.x / 2);

      await _audio.initialize();
      await _audio.startOrResumeBgm();
      await adsManager.initialize();
      await purchaseManager.initialize();

      final int sessionCount = await retentionManager.trackSessionStart();
      unawaited(analyticsManager.trackSessionStart(sessionCount: sessionCount));

      _setState(StreetRushState.menu);
      pauseEngine();
    } catch (e, stack) {
      print('FATAL ERROR in StreetRushGame.onLoad(): $e\n$stack');
      rethrow;
    }
  }

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    if (!isLoaded) {
      return;
    }
    _layoutForCurrentSize(gameSize);
  }

  @override
  void update(double dt) {
    if (_state != StreetRushState.playing) {
      return;
    }

    super.update(dt);
    if (_state != StreetRushState.playing) {
      return;
    }

    _updateDistanceScore(dt);
    _updateEnemySpawning(dt);
    _updateCoinSpawning(dt);
    _updateCoinMagnetCollection();
    _updateMissionFeedback(dt);
  }

  void onHorizontalDrag(double canvasX) {
    if (_state != StreetRushState.playing) {
      return;
    }
    playerCar.setTargetX(canvasX);
  }

  void _layoutForCurrentSize(Vector2 gameSize) {
    playerCar.onScreenResize(gameSize);

    _baseTrafficSpeed = (gameSize.y * 0.48).clamp(230.0, 620.0).toDouble();
    _baseBackgroundSpeed = _baseTrafficSpeed * 0.9;

    _roadParallax
      ..position = Vector2.zero()
      ..size = gameSize;

    _dragInputLayer
      ..position = Vector2.zero()
      ..size = gameSize;

    _recomputeDynamicDifficulty();
  }

  void _applyUpgradesToPlayer() {
    final modifiers = upgradeSystem.activeModifiers;
    playerCar.applyUpgradeModifiers(
      handlingMultiplier: modifiers.handlingMultiplier,
      coinMagnetRadiusMultiplier: modifiers.coinMagnetRadiusMultiplier,
    );
  }

  void _updateDistanceScore(double dt) {
    _distanceProgress += distancePerSecond * dt;
    final int nextScore = _distanceProgress.floor();
    if (nextScore == _distanceScore) {
      return;
    }

    _distanceScore = nextScore;
    distanceScoreNotifier.value = _distanceScore;

    final int milestone = _distanceScore ~/ 500;
    if (milestone > 0 && milestone > _lastDistanceEventMilestone) {
      _lastDistanceEventMilestone = milestone;
      unawaited(
        analyticsManager.trackDistanceReached(distance: _distanceScore),
      );
    }

    _recomputeDynamicDifficulty();

    final completion = missionSystem.updateDistanceProgress(_distanceScore);
    if (completion != null) {
      unawaited(_handleMissionCompletion(completion));
    }
  }

  void _recomputeDynamicDifficulty() {
    if (_baseTrafficSpeed == 0) {
      return;
    }

    final double raw = (_distanceScore / difficultyRampDistance)
        .clamp(0.0, 1.0)
        .toDouble();
    final double smoothed = raw * raw * (3 - (2 * raw));

    _currentEnemySpawnInterval =
        _lerp(baseEnemySpawnInterval, minEnemySpawnInterval, smoothed);
    _currentTrafficSpeed =
        _baseTrafficSpeed * _lerp(1, maxTrafficSpeedMultiplier, smoothed);
    _currentBackgroundSpeed =
        _baseBackgroundSpeed * _lerp(1, maxBackgroundSpeedMultiplier, smoothed);

    _roadParallax.parallax?.baseVelocity = Vector2(0, _currentBackgroundSpeed);
    _syncActiveEntitySpeeds();
  }

  double _lerp(double a, double b, double t) => a + ((b - a) * t);

  void _syncActiveEntitySpeeds() {
    for (final enemy in children.whereType<EnemyCar>()) {
      enemy.speed = _currentTrafficSpeed;
    }
    for (final coin in children.whereType<Coin>()) {
      coin.speed = _currentTrafficSpeed;
    }
  }

  void _updateEnemySpawning(double dt) {
    _enemySpawnAccumulator += dt;
    while (_enemySpawnAccumulator >= _currentEnemySpawnInterval) {
      _enemySpawnAccumulator -= _currentEnemySpawnInterval;
      _spawnEnemyCar();
    }
  }

  void _updateCoinSpawning(double dt) {
    _coinSpawnAccumulator += dt;
    while (_coinSpawnAccumulator >= coinSpawnInterval) {
      _coinSpawnAccumulator -= coinSpawnInterval;
      _spawnCoin();
    }
  }

  void _spawnEnemyCar() {
    final Vector2 enemySize = EnemyCar.sizeForScreen(size);
    final double minX = enemySize.x / 2;
    final double maxX = size.x - (enemySize.x / 2);
    final double randomX = minX + (_random.nextDouble() * (maxX - minX));

    add(
      EnemyCar(
        sprite: _enemySprite,
        spawnPosition: Vector2(randomX, -enemySize.y / 2),
        carSize: enemySize,
        speed: _currentTrafficSpeed,
      ),
    );
  }

  void _spawnCoin() {
    final Vector2 coinSize = Coin.sizeForScreen(size);
    final double minX = coinSize.x / 2;
    final double maxX = size.x - (coinSize.x / 2);
    final double spawnY = -coinSize.y / 2;
    const int maxAttempts = 10;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final double randomX = minX + (_random.nextDouble() * (maxX - minX));
      final Vector2 spawnPosition = Vector2(randomX, spawnY);
      final Rect candidateRect = _rectFromCenter(spawnPosition, coinSize);

      if (_canSpawnCoinAt(candidateRect)) {
        add(
          Coin(
            sprite: _coinSprite,
            spawnPosition: spawnPosition,
            coinSize: coinSize,
            speed: _currentTrafficSpeed,
          ),
        );
        return;
      }
    }
  }

  bool _canSpawnCoinAt(Rect candidateRect) {
    for (final enemy in children.whereType<EnemyCar>()) {
      if (!enemy.isRemoving &&
          candidateRect.overlaps(_rectFromCenter(enemy.position, enemy.size))) {
        return false;
      }
    }

    for (final coin in children.whereType<Coin>()) {
      if (!coin.isRemoving &&
          candidateRect.overlaps(_rectFromCenter(coin.position, coin.size))) {
        return false;
      }
    }

    return true;
  }

  Rect _rectFromCenter(Vector2 center, Vector2 componentSize) {
    return Rect.fromCenter(
      center: Offset(center.x, center.y),
      width: componentSize.x,
      height: componentSize.y,
    );
  }

  void _updateCoinMagnetCollection() {
    final double magnetRadius = playerCar.coinMagnetRadius;
    if (magnetRadius <= 0) {
      return;
    }

    final double radiusSquared = magnetRadius * magnetRadius;
    final Vector2 playerCenter = playerCar.position;

    for (final coin in children.whereType<Coin>().toList(growable: false)) {
      if (!coin.isMounted || coin.isRemoving) {
        continue;
      }

      final double dx = coin.position.x - playerCenter.x;
      final double dy = coin.position.y - playerCenter.y;
      if ((dx * dx) + (dy * dy) <= radiusSquared) {
        collectCoin(coin);
      }
    }
  }

  void collectCoin(Coin coin) {
    if (_state != StreetRushState.playing || !coin.isMounted || coin.isRemoving) {
      return;
    }

    if (coin.sprite != null) {
      add(
        CoinPickupEffect(
          sprite: coin.sprite!,
          worldPosition: coin.position.clone(),
          effectSize: coin.size.clone(),
        ),
      );
    }

    coin.removeFromParent();
    _coinCount += 1;
    coinCountNotifier.value = _coinCount;

    final int coinMilestone = _coinCount ~/ 10;
    if (coinMilestone > 0 && coinMilestone > _lastCoinEventMilestone) {
      _lastCoinEventMilestone = coinMilestone;
      unawaited(
        analyticsManager.trackCoinsCollected(totalRunCoins: _coinCount),
      );
    }

    unawaited(_audio.playCoinPickup());

    final completion = missionSystem.updateCoinsProgress(_coinCount);
    if (completion != null) {
      unawaited(_handleMissionCompletion(completion));
    }
  }

  Future<void> _handleMissionCompletion(MissionCompletion completion) async {
    _missionCompletedThisRun = true;
    final int reward = completion.completedMission.reward;
    await dataManager.addCoins(reward);
    _setMissionFeedback('Mission Complete! +$reward coins');
  }

  void _setMissionFeedback(String message) {
    missionFeedbackNotifier.value = message;
    _missionFeedbackTimeLeft = 2.4;
  }

  void _updateMissionFeedback(double dt) {
    if (_missionFeedbackTimeLeft <= 0) {
      return;
    }

    _missionFeedbackTimeLeft -= dt;
    if (_missionFeedbackTimeLeft <= 0) {
      missionFeedbackNotifier.value = null;
      _missionFeedbackTimeLeft = 0;
    }
  }

  void triggerGameOver() {
    if (_state != StreetRushState.playing) {
      return;
    }

    _newRecordThisRun = _distanceScore > dataManager.highScore;
    _distanceDeltaVsLastRun = _distanceScore - dataManager.lastRunDistance;
    _challengeTargetDistance = shareManager.challengeDistanceFor(
      distance: _distanceScore,
      offset: balanceConfig.shareChallengeOffsetDistance,
    );

    _setState(StreetRushState.gameOver);
    debugPrint('Game Over');
    pauseEngine();

    add(CrashFlashEffect(viewportSize: size.clone()));

    unawaited(_audio.playCrash());
    unawaited(
      analyticsManager.trackGameOver(
        distance: _distanceScore,
        runCoins: _coinCount,
        revived: _reviveUsedThisRun,
      ),
    );
    unawaited(
      adsManager.onGameOver(adsRemoved: purchaseManager.isRemoveAdsPurchased),
    );
    unawaited(_finalizeRunPersistence());
    unawaited(
      reviewPromptManager.maybePromptAfterPositiveRun(
        distance: _distanceScore,
        newRecord: _newRecordThisRun,
        missionCompleted: _missionCompletedThisRun,
      ),
    );
  }

  Future<void> _finalizeRunPersistence() async {
    final int coinsDelta = _coinCount - _persistedRunCoins;
    if (coinsDelta > 0) {
      await dataManager.addCoins(coinsDelta);
      _persistedRunCoins = _coinCount;
    }

    final bool isNewRecordAtCurrentDistance =
        _distanceScore > dataManager.highScore;
    if (isNewRecordAtCurrentDistance) {
      _newRecordThisRun = true;

      if (!_newRecordBonusGranted && balanceConfig.newRecordBonusCoins > 0) {
        await dataManager.addCoins(balanceConfig.newRecordBonusCoins);
        _newRecordBonusGranted = true;
      }
    }

    if (_distanceScore > _persistedRunDistance) {
      _persistedRunDistance = _distanceScore;
      await dataManager.updateHighScoreIfBetter(_distanceScore);
    }

    if (dataManager.lastRunDistance != _distanceScore) {
      await dataManager.setLastRunDistance(_distanceScore);
    }
  }

  void startGame() {
    _clearRunEntities();
    _resetRunData();
    _applyUpgradesToPlayer();
    playerCar.resetForNewRun(size);
    missionSystem.beginRun();
    unawaited(analyticsManager.trackGameStart());
    _setState(StreetRushState.playing);

    resumeEngine();
    unawaited(_audio.startOrResumeBgm());
  }

  void restartGame() {
    if (_state == StreetRushState.gameOver) {
      unawaited(_finalizeRunPersistence());
    }
    startGame();
  }

  void openGarage() {
    if (_state == StreetRushState.playing) {
      return;
    }
    _setState(StreetRushState.garage);
    pauseEngine();
  }

  void backToMenu() {
    if (_state == StreetRushState.gameOver) {
      unawaited(_finalizeRunPersistence());
    }
    _setState(StreetRushState.menu);
    pauseEngine();
  }

  Future<String> purchaseHandlingUpgrade() async {
    final int cost = handlingUpgradeCost;
    final result = await upgradeSystem.purchase(UpgradeType.handling);
    if (result.success) {
      _applyUpgradesToPlayer();
      unawaited(
        analyticsManager.trackUpgradePurchase(
          upgrade: 'handling',
          level: handlingLevel,
          cost: cost,
        ),
      );
    }
    return result.message;
  }

  Future<String> purchaseCoinMagnetUpgrade() async {
    final int cost = coinMagnetUpgradeCost;
    final result = await upgradeSystem.purchase(UpgradeType.coinMagnet);
    if (result.success) {
      _applyUpgradesToPlayer();
      unawaited(
        analyticsManager.trackUpgradePurchase(
          upgrade: 'coin_magnet',
          level: coinMagnetLevel,
          cost: cost,
        ),
      );
    }
    return result.message;
  }

  Future<DailyRewardResult> claimDailyRewardIfAvailable() async {
    final result = await retentionManager.claimDailyRewardIfAvailable();
    if (result.granted) {
      unawaited(
        analyticsManager.trackDailyReward(
          reward: result.rewardCoins,
          streak: result.streak,
        ),
      );
    }
    return result;
  }

  Future<bool> buyRemoveAds() async {
    final bool success = await purchaseManager.buyProduct(PurchaseCatalog.removeAds);
    return success;
  }

  Future<bool> buyCoinPackSmall() async {
    final bool success = await purchaseManager.buyProduct(PurchaseCatalog.coinPackSmall);
    return success;
  }

  Future<bool> buyCoinPackLarge() async {
    final bool success = await purchaseManager.buyProduct(PurchaseCatalog.coinPackLarge);
    return success;
  }

  Future<void> restorePurchases() async {
    await purchaseManager.restorePurchases();
  }

  Future<bool> tryReviveViaRewardedAd() async {
    if (_state != StreetRushState.gameOver || _reviveUsedThisRun) {
      return false;
    }

    final bool rewarded = await adsManager.showRewarded(
      onRewardEarned: () async {
        _reviveUsedThisRun = true;
        _clearRunEntities();
        _setState(StreetRushState.playing);
        resumeEngine();
        await analyticsManager.trackAdWatched(
          adType: 'rewarded',
          placement: 'revive',
        );
        await analyticsManager.trackReviveUsed();
      },
    );

    return rewarded;
  }

  Future<bool> tryRewardedCoins() async {
    final bool rewarded = await adsManager.showRewarded(
      onRewardEarned: () async {
        final int reward = balanceConfig.rewardedCoinBonus;
        await dataManager.addCoins(reward);
        await analyticsManager.trackAdWatched(
          adType: 'rewarded',
          placement: 'coins_bonus',
          reward: reward,
        );
      },
    );
    return rewarded;
  }

  Future<bool> shareRunChallenge() async {
    if (_state != StreetRushState.gameOver) {
      return false;
    }

    final String referralCode = shareReferralCode;
    final String text = shareManager.buildChallengeShareText(
      distance: _distanceScore,
      challengeDistance: _challengeTargetDistance,
      bestDistance: dataManager.highScore,
      referralCode: referralCode,
    );

    final bool shared = await shareManager.shareText(text);
    if (shared) {
      unawaited(
        analyticsManager.trackShareChallenge(
          distance: _distanceScore,
          challengeDistance: _challengeTargetDistance,
          referralCode: referralCode,
        ),
      );
    }

    return shared;
  }

  void handleAppLifecyclePause() {
    if (_state == StreetRushState.playing) {
      _resumeEngineAfterLifecycle = true;
      pauseEngine();
    } else {
      _resumeEngineAfterLifecycle = false;
    }

    if (_state == StreetRushState.gameOver) {
      unawaited(_finalizeRunPersistence());
    }

    _audio.pauseBgm();
  }

  void handleAppLifecycleResume() {
    if (_state == StreetRushState.playing && _resumeEngineAfterLifecycle) {
      resumeEngine();
    }
    _resumeEngineAfterLifecycle = false;
    unawaited(_audio.startOrResumeBgm());
  }

  void _clearRunEntities() {
    for (final enemy in children.whereType<EnemyCar>().toList(growable: false)) {
      enemy.removeFromParent();
    }
    for (final coin in children.whereType<Coin>().toList(growable: false)) {
      coin.removeFromParent();
    }
    for (final effect in children.whereType<CoinPickupEffect>().toList(growable: false)) {
      effect.removeFromParent();
    }
    for (final flash in children.whereType<CrashFlashEffect>().toList(growable: false)) {
      flash.removeFromParent();
    }
  }

  void _resetRunData() {
    _enemySpawnAccumulator = 0;
    _coinSpawnAccumulator = 0;
    _distanceProgress = 0;
    _distanceScore = 0;
    _coinCount = 0;
    _persistedRunCoins = 0;
    _persistedRunDistance = 0;
    _newRecordBonusGranted = false;
    _reviveUsedThisRun = false;
    _missionCompletedThisRun = false;
    _newRecordThisRun = false;
    _distanceDeltaVsLastRun = 0;
    _challengeTargetDistance = 0;
    _lastDistanceEventMilestone = 0;
    _lastCoinEventMilestone = 0;
    _missionFeedbackTimeLeft = 0;
    missionFeedbackNotifier.value = null;
    distanceScoreNotifier.value = _distanceScore;
    coinCountNotifier.value = _coinCount;

    _recomputeDynamicDifficulty();
  }

  void _setState(StreetRushState nextState) {
    _state = nextState;
    _syncOverlays();
  }

  void _syncOverlays() {
    overlays
      ..remove(hudOverlay)
      ..remove(menuOverlay)
      ..remove(garageOverlay)
      ..remove(gameOverOverlay);

    switch (_state) {
      case StreetRushState.menu:
        overlays.add(menuOverlay);
        break;
      case StreetRushState.garage:
        overlays.add(garageOverlay);
        break;
      case StreetRushState.playing:
        overlays.add(hudOverlay);
        break;
      case StreetRushState.gameOver:
        overlays.add(gameOverOverlay);
        break;
    }
  }

  @override
  void onRemove() {
    if (_state == StreetRushState.gameOver) {
      unawaited(_finalizeRunPersistence());
    }
    distanceScoreNotifier.dispose();
    coinCountNotifier.dispose();
    missionFeedbackNotifier.dispose();
    missionSystem.dispose();
    _audio.stopAll();
    adsManager.dispose();
    unawaited(purchaseManager.dispose());
    super.onRemove();
  }
}

class _DragInputLayer extends PositionComponent
    with DragCallbacks, HasGameReference<StreetRushGame> {
  _DragInputLayer() : super(anchor: Anchor.topLeft, priority: 100);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    game.onHorizontalDrag(event.canvasPosition.x);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    game.onHorizontalDrag(event.canvasEndPosition.x);
  }
}