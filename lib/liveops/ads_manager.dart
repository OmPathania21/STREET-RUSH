import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';

class AdsManager {
  AdsManager({
    required this.rewardedAdUnitId,
    required this.interstitialAdUnitId,
    this.interstitialFrequency = 3,
  });

  final String rewardedAdUnitId;
  final String interstitialAdUnitId;
  final int interstitialFrequency;

  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;
  bool _initialized = false;
  bool _showingInterstitial = false;
  int _gameOverCount = 0;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      print('Google Mobile Ads initialization failed: $e');
    }
    _initialized = true;
    _loadRewarded();
    _loadInterstitial();
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd?.dispose();
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (_) {
          _rewardedAd = null;
        },
      ),
    );
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd?.dispose();
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (_) {
          _interstitialAd = null;
        },
      ),
    );
  }

  bool get hasRewardedReady => _rewardedAd != null;

  Future<bool> showRewarded({
    required Future<void> Function() onRewardEarned,
    Future<void> Function()? onShown,
    Future<void> Function()? onDismissed,
  }) async {
    final ad = _rewardedAd;
    if (ad == null) {
      _loadRewarded();
      return false;
    }

    _rewardedAd = null;
    bool rewarded = false;
    final Completer<bool> completion = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) async {
        if (onShown != null) {
          await onShown();
        }
      },
      onAdDismissedFullScreenContent: (_) async {
        ad.dispose();
        _loadRewarded();
        if (onDismissed != null) {
          await onDismissed();
        }
        if (!completion.isCompleted) {
          completion.complete(rewarded);
        }
      },
      onAdFailedToShowFullScreenContent: (_, __) async {
        ad.dispose();
        _loadRewarded();
        if (!completion.isCompleted) {
          completion.complete(false);
        }
      },
    );

    ad.show(
      onUserEarnedReward: (_, __) async {
        rewarded = true;
        await onRewardEarned();
      },
    );

    return completion.future;
  }

  Future<void> onGameOver({required bool adsRemoved}) async {
    if (adsRemoved || _showingInterstitial) {
      return;
    }

    _gameOverCount += 1;
    if (_gameOverCount % interstitialFrequency != 0) {
      return;
    }

    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitial();
      return;
    }

    _interstitialAd = null;
    _showingInterstitial = true;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (_) {
        _showingInterstitial = false;
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (_, __) {
        _showingInterstitial = false;
        ad.dispose();
        _loadInterstitial();
      },
    );

    ad.show();
  }

  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
  }
}
