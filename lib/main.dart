import 'package:flame/game.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';

import 'game/street_rush_game.dart';
import 'liveops/ads_manager.dart';
import 'liveops/analytics_manager.dart';
import 'liveops/game_balance_config.dart';
import 'liveops/purchase_manager.dart';
import 'liveops/review_prompt_manager.dart';
import 'liveops/retention_manager.dart';
import 'liveops/share_manager.dart';
import 'meta/data_manager.dart';
import 'meta/mission_system.dart';
import 'meta/upgrade_system.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final dataManager = await DataManager.getInstance();
    final upgradeSystem = UpgradeSystem(dataManager: dataManager);
    final missionSystem = MissionSystem();
    
    // Initialize Firebase Analytics safely
    FirebaseAnalytics? firebaseAnalytics;
    try {
      firebaseAnalytics = FirebaseAnalytics.instance;
    } catch (_) {
      print('Firebase Analytics initialization failed, continuing without analytics');
    }
    final analyticsManager = AnalyticsManager(firebaseAnalytics);
    const balanceConfig = GameBalanceConfig();
    final adsManager = AdsManager(
      rewardedAdUnitId: 'ca-app-pub-3940256099942544/5224354917',
      interstitialAdUnitId: 'ca-app-pub-3940256099942544/1033173712',
      interstitialFrequency: balanceConfig.interstitialEveryNGameOvers,
    );
    final retentionManager = RetentionManager(dataManager: dataManager);
    const shareManager = GrowthShareManager();
    final reviewPromptManager = ReviewPromptManager(
      dataManager: dataManager,
      analyticsManager: analyticsManager,
      minSessionsBeforePrompt: balanceConfig.reviewMinSessions,
      minDistanceForPrompt: balanceConfig.reviewDistanceThreshold,
      promptCooldownDays: balanceConfig.reviewPromptCooldownDays,
      maxLifetimePrompts: balanceConfig.maxReviewPrompts,
    );
    final purchaseManager = PurchaseManager(
      dataManager: dataManager,
      analyticsManager: analyticsManager,
    );

    runApp(
      StreetRushApp(
        dataManager: dataManager,
        upgradeSystem: upgradeSystem,
        missionSystem: missionSystem,
        adsManager: adsManager,
        analyticsManager: analyticsManager,
        retentionManager: retentionManager,
        shareManager: shareManager,
        reviewPromptManager: reviewPromptManager,
        purchaseManager: purchaseManager,
        balanceConfig: balanceConfig,
      ),
    );
  } catch (e, stack) {
    print('FATAL ERROR in main(): $e\n$stack');
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Error: $e'),
          ),
        ),
      ),
    );
  }
}

class StreetRushApp extends StatefulWidget {
  const StreetRushApp({
    super.key,
    required this.dataManager,
    required this.upgradeSystem,
    required this.missionSystem,
    required this.adsManager,
    required this.analyticsManager,
    required this.retentionManager,
    required this.shareManager,
    required this.reviewPromptManager,
    required this.purchaseManager,
    required this.balanceConfig,
  });

  final DataManager dataManager;
  final UpgradeSystem upgradeSystem;
  final MissionSystem missionSystem;
  final AdsManager adsManager;
  final AnalyticsManager analyticsManager;
  final RetentionManager retentionManager;
  final GrowthShareManager shareManager;
  final ReviewPromptManager reviewPromptManager;
  final PurchaseManager purchaseManager;
  final GameBalanceConfig balanceConfig;

  @override
  State<StreetRushApp> createState() => _StreetRushAppState();
}

class _StreetRushAppState extends State<StreetRushApp>
    with WidgetsBindingObserver {
  late final StreetRushGame _game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = StreetRushGame(
      dataManager: widget.dataManager,
      upgradeSystem: widget.upgradeSystem,
      missionSystem: widget.missionSystem,
      adsManager: widget.adsManager,
      analyticsManager: widget.analyticsManager,
      purchaseManager: widget.purchaseManager,
      retentionManager: widget.retentionManager,
      shareManager: widget.shareManager,
      reviewPromptManager: widget.reviewPromptManager,
      balanceConfig: widget.balanceConfig,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _game.handleAppLifecyclePause();
        break;
      case AppLifecycleState.resumed:
        _game.handleAppLifecycleResume();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Street Rush',
      home: Scaffold(
        body: GameWidget<StreetRushGame>(
          game: _game,
          initialActiveOverlays: const [StreetRushGame.menuOverlay],
          overlayBuilderMap: {
            StreetRushGame.hudOverlay: (context, game) {
              return _HudOverlay(game: game);
            },
            StreetRushGame.menuOverlay: (context, game) {
              return _MainMenuOverlay(game: game);
            },
            StreetRushGame.garageOverlay: (context, game) {
              return _GarageOverlay(game: game);
            },
            StreetRushGame.gameOverOverlay: (context, game) {
              return _GameOverOverlay(game: game);
            },
          },
        ),
      ),
    );
  }
}

class _HudOverlay extends StatelessWidget {
  const _HudOverlay({required this.game});

  final StreetRushGame game;

  @override
  Widget build(BuildContext context) {
    return _OverlayEnterTransition(
      duration: const Duration(milliseconds: 180),
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ValueListenableBuilder<int>(
                        valueListenable: game.distanceScoreNotifier,
                        builder: (context, score, _) {
                          return _HudChip(
                            icon: Icons.route_rounded,
                            label: 'Distance',
                            value: '$score m',
                          );
                        },
                      ),
                      ValueListenableBuilder<int>(
                        valueListenable: game.coinCountNotifier,
                        builder: (context, coins, _) {
                          return _HudChip(
                            icon: Icons.monetization_on_rounded,
                            label: 'Run Coins',
                            value: '$coins',
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AnimatedBuilder(
                    animation: Listenable.merge(
                      [
                        game.missionSystem.missionNotifier,
                        game.missionSystem.progressNotifier,
                      ],
                    ),
                    builder: (context, _) {
                      final mission = game.missionSystem.currentMission;
                      return _MissionChip(
                        missionTitle: mission.title,
                        progress:
                            '${game.missionProgress}/${mission.target} ${mission.progressUnit}',
                        reward: mission.reward,
                      );
                    },
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: ValueListenableBuilder<String?>(
                valueListenable: game.missionFeedbackNotifier,
                builder: (context, message, _) {
                  if (message == null) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xE6268A44),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionChip extends StatelessWidget {
  const _MissionChip({
    required this.missionTitle,
    required this.progress,
    required this.reward,
  });

  final String missionTitle;
  final String progress;
  final int reward;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xCC0F1319),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x5542607A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            missionTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Progress: $progress  |  Reward: $reward coins',
            style: const TextStyle(
              color: Color(0xFFBDD4EA),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC101418),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x553A4655)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _MainMenuOverlay extends StatelessWidget {
  const _MainMenuOverlay({required this.game});

  final StreetRushGame game;

  @override
  Widget build(BuildContext context) {
    return _OverlayEnterTransition(
      child: ColoredBox(
        color: const Color(0xB3141820),
        child: Center(
          child: Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: const Color(0xDD0F1319),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x553A4655)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Street Rush',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 18),
                ValueListenableBuilder<int>(
                  valueListenable: game.dataManager.totalCoinsNotifier,
                  builder: (context, coins, _) {
                    return Text(
                      'Bank: $coins coins',
                      style: const TextStyle(
                        color: Color(0xFFB9C3D3),
                        fontSize: 14,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder<int>(
                  valueListenable: game.dataManager.highScoreNotifier,
                  builder: (context, highScore, _) {
                    return Text(
                      'Best Distance: $highScore m',
                      style: const TextStyle(
                        color: Color(0xFFB9C3D3),
                        fontSize: 14,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: game.startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Start'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: game.openGarage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE3F2FD),
                      side: const BorderSide(color: Color(0xFF546E7A)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Garage'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () async {
                      final result = await game.claimDailyRewardIfAvailable();
                      if (!context.mounted) {
                        return;
                      }
                      final message = result.granted
                          ? 'Daily reward claimed: +${result.rewardCoins} coins (Streak ${result.streak})'
                          : 'Daily reward already claimed today.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFFFD54F),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Claim Daily Reward'),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final rewarded = await game.tryRewardedCoins();
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            rewarded
                                ? 'Ad watched. +${game.balanceConfig.rewardedCoinBonus} bonus coins!'
                                : 'No rewarded ad ready yet. Try again shortly.',
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC8E6C9),
                      side: const BorderSide(color: Color(0xFF4A6A50)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Watch Ad (+Bonus Coins)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GarageOverlay extends StatelessWidget {
  const _GarageOverlay({required this.game});

  final StreetRushGame game;

  @override
  Widget build(BuildContext context) {
    return _OverlayEnterTransition(
      child: ColoredBox(
        color: const Color(0xCC0C1117),
        child: Center(
          child: AnimatedBuilder(
            animation: game.garageListenable,
            builder: (context, _) {
              return Container(
                width: 340,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  color: const Color(0xEE121921),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x5550728E)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Garage',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Bank: ${game.bankCoins} coins',
                      style: const TextStyle(
                        color: Color(0xFFE8F0FC),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _UpgradeTile(
                      title: 'Handling',
                      level: game.handlingLevel,
                      maxed: game.isHandlingMax,
                      nextCost: game.handlingUpgradeCost,
                      effectText:
                          'Faster lateral response (${(1 + game.handlingLevel * 0.12).toStringAsFixed(2)}x)',
                      buttonText: game.isHandlingMax
                          ? 'Maxed'
                          : 'Upgrade (${game.handlingUpgradeCost})',
                      onPressed: game.isHandlingMax
                          ? null
                          : () async {
                              final message =
                                  await game.purchaseHandlingUpgrade();
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                            },
                    ),
                    const SizedBox(height: 12),
                    _UpgradeTile(
                      title: 'Coin Magnet',
                      level: game.coinMagnetLevel,
                      maxed: game.isCoinMagnetMax,
                      nextCost: game.coinMagnetUpgradeCost,
                      effectText:
                          'Larger auto-collect radius (${(1 + game.coinMagnetLevel * 0.20).toStringAsFixed(2)}x)',
                      buttonText: game.isCoinMagnetMax
                          ? 'Maxed'
                          : 'Upgrade (${game.coinMagnetUpgradeCost})',
                      onPressed: game.isCoinMagnetMax
                          ? null
                          : () async {
                              final message =
                                  await game.purchaseCoinMagnetUpgrade();
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                            },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Store',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<bool>(
                      valueListenable: game.dataManager.removeAdsNotifier,
                      builder: (context, removeAds, _) {
                        return Text(
                          removeAds
                              ? 'Ads: Removed'
                              : 'Ads: Active',
                          style: const TextStyle(
                            color: Color(0xFFD6E3F2),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    if (!game.isRemoveAdsPurchased)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: game.isIapAvailable
                              ? () async {
                                  final started = await game.buyRemoveAds();
                                  if (!context.mounted) {
                                    return;
                                  }
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        started
                                            ? 'Purchase flow started for Remove Ads.'
                                            : 'Unable to start Remove Ads purchase.',
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6D4C41),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Buy Remove Ads'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: game.isIapAvailable
                                ? () async {
                                    final started = await game.buyCoinPackSmall();
                                    if (!context.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          started
                                              ? 'Small coin pack purchase started.'
                                              : 'Unable to start small coin pack purchase.',
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE0F2F1),
                              side: const BorderSide(color: Color(0xFF5B8480)),
                            ),
                            child: const Text('Small Pack'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: game.isIapAvailable
                                ? () async {
                                    final started = await game.buyCoinPackLarge();
                                    if (!context.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          started
                                              ? 'Large coin pack purchase started.'
                                              : 'Unable to start large coin pack purchase.',
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE0F2F1),
                              side: const BorderSide(color: Color(0xFF5B8480)),
                            ),
                            child: const Text('Large Pack'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: game.isIapAvailable
                            ? () async {
                                await game.restorePurchases();
                                if (!context.mounted) {
                                  return;
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Restore purchases requested.'),
                                  ),
                                );
                              }
                            : null,
                        child: const Text('Restore Purchases'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: game.backToMenu,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Color(0x667A96AD)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UpgradeTile extends StatelessWidget {
  const _UpgradeTile({
    required this.title,
    required this.level,
    required this.maxed,
    required this.nextCost,
    required this.effectText,
    required this.buttonText,
    required this.onPressed,
  });

  final String title;
  final int level;
  final bool maxed;
  final int nextCost;
  final String effectText;
  final String buttonText;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC18232E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x554F6B82)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title  |  Level $level',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            effectText,
            style: const TextStyle(
              color: Color(0xFFBED5E8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          if (!maxed)
            Text(
              'Next cost: $nextCost coins',
              style: const TextStyle(
                color: Color(0xFF9DB4C8),
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed == null ? null : () => onPressed!.call(),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    maxed ? const Color(0xFF455A64) : const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.game});

  final StreetRushGame game;

  @override
  Widget build(BuildContext context) {
    return _OverlayEnterTransition(
      child: ColoredBox(
        color: const Color(0xBB120F15),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: const Color(0xDD121821),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0x553A4655)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Game Over',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Distance: ${game.distanceScore} m',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Coins: ${game.coinCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Personal Best: ${game.isNewRecordThisRun ? game.distanceScore : game.highScore} m',
                  style: const TextStyle(
                    color: Color(0xFFDDE6F1),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  game.distanceDeltaVsLastRun >= 0
                      ? 'Progress: +${game.distanceDeltaVsLastRun} m vs last run'
                      : 'Progress: ${game.distanceDeltaVsLastRun} m vs last run',
                  style: TextStyle(
                    color: game.distanceDeltaVsLastRun >= 0
                        ? const Color(0xFF9BE7A4)
                        : const Color(0xFFE6A8A8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (game.isNewRecordThisRun) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC2E7D32),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'New Record! +${game.balanceConfig.newRecordBonusCoins} bonus coins',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ValueListenableBuilder<int>(
                  valueListenable: game.dataManager.totalCoinsNotifier,
                  builder: (context, bank, _) {
                    return Text(
                      'Bank: $bank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: Listenable.merge(
                    [
                      game.missionSystem.missionNotifier,
                      game.missionSystem.progressNotifier,
                    ],
                  ),
                  builder: (context, _) {
                    return Text(
                      'Next Mission: ${game.missionSystem.currentMission.title}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFCFD8E3),
                        fontSize: 13,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Challenge your friends: ${game.challengeTargetDistance} m',
                  style: const TextStyle(
                    color: Color(0xFFBFD7FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final shared = await game.shareRunChallenge();
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            shared
                                ? 'Challenge shared successfully!'
                                : 'Unable to open share dialog right now.',
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFE082),
                      side: const BorderSide(color: Color(0xFF9A7A36)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Share Score Challenge'),
                  ),
                ),
                const SizedBox(height: 10),
                if (game.canUseReviveAd) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final rewarded = await game.tryReviveViaRewardedAd();
                        if (!context.mounted || rewarded) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No revive ad available right now.'),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8F00),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Revive (Watch Ad)'),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () async {
                      final rewarded = await game.tryRewardedCoins();
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            rewarded
                                ? 'Ad watched. Bonus coins added to your bank.'
                                : 'No rewarded ad ready yet.',
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD0E8FF),
                      side: const BorderSide(color: Color(0xFF4D6580)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Watch Ad (+Coins)'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: game.restartGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF43A047),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Restart'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayEnterTransition extends StatelessWidget {
  const _OverlayEnterTransition({
    required this.child,
    this.duration = const Duration(milliseconds: 240),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, value, builtChild) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.97 + (0.03 * value),
            child: builtChild,
          ),
        );
      },
    );
  }
}