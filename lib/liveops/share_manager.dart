import 'package:share_plus/share_plus.dart';

class GrowthShareManager {
  const GrowthShareManager({
    this.storeUrl =
        'https://play.google.com/store/apps/details?id=com.ompathania.streetrush',
  });

  final String storeUrl;

  int challengeDistanceFor({
    required int distance,
    required int offset,
  }) {
    final int normalizedDistance = distance < 0 ? 0 : distance;
    final int normalizedOffset = offset < 0 ? 0 : offset;
    return normalizedDistance + normalizedOffset;
  }

  String referralCodeForPlayer({
    required int highScore,
    required int sessionCount,
  }) {
    final int encoded = ((highScore * 31) + (sessionCount * 17) + 97)
        .clamp(1000, 999999)
        .toInt();
    return 'SR$encoded';
  }

  String buildChallengeShareText({
    required int distance,
    required int challengeDistance,
    required int bestDistance,
    required String referralCode,
  }) {
    return 'I just hit $distance m in Street Rush!\n'
        'My best is $bestDistance m.\n'
        'Can you beat my challenge of $challengeDistance m?\n\n'
        'Download and race: $storeUrl\n'
        'Referral: $referralCode';
  }

  Future<bool> shareText(String text) async {
    try {
      await Share.share(text);
      return true;
    } catch (_) {
      return false;
    }
  }
}
