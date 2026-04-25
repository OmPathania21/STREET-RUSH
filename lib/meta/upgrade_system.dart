import 'dart:math' as math;

import 'data_manager.dart';

enum UpgradeType {
  handling,
  coinMagnet,
}

class UpgradeDefinition {
  const UpgradeDefinition({
    required this.type,
    required this.title,
    required this.description,
    required this.baseCost,
    required this.costGrowth,
    required this.maxLevel,
  });

  final UpgradeType type;
  final String title;
  final String description;
  final int baseCost;
  final double costGrowth;
  final int maxLevel;

  int costForLevel(int currentLevel) {
    return (baseCost * math.pow(costGrowth, currentLevel)).round();
  }
}

class UpgradePurchaseResult {
  const UpgradePurchaseResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class PlayerUpgradeModifiers {
  const PlayerUpgradeModifiers({
    required this.handlingMultiplier,
    required this.coinMagnetRadiusMultiplier,
  });

  final double handlingMultiplier;
  final double coinMagnetRadiusMultiplier;
}

class UpgradeSystem {
  UpgradeSystem({required this.dataManager});

  final DataManager dataManager;

  static const UpgradeDefinition handlingDefinition = UpgradeDefinition(
    type: UpgradeType.handling,
    title: 'Handling',
    description: 'Improves lateral steering response and max slide speed.',
    baseCost: 40,
    costGrowth: 1.55,
    maxLevel: 8,
  );

  static const UpgradeDefinition coinMagnetDefinition = UpgradeDefinition(
    type: UpgradeType.coinMagnet,
    title: 'Coin Magnet',
    description: 'Increases automatic coin collection radius around the car.',
    baseCost: 55,
    costGrowth: 1.65,
    maxLevel: 8,
  );

  UpgradeDefinition definitionFor(UpgradeType type) {
    switch (type) {
      case UpgradeType.handling:
        return handlingDefinition;
      case UpgradeType.coinMagnet:
        return coinMagnetDefinition;
    }
  }

  int levelFor(UpgradeType type) {
    switch (type) {
      case UpgradeType.handling:
        return dataManager.handlingLevel;
      case UpgradeType.coinMagnet:
        return dataManager.coinMagnetLevel;
    }
  }

  int costForNextLevel(UpgradeType type) {
    final definition = definitionFor(type);
    final level = levelFor(type);
    return definition.costForLevel(level);
  }

  bool isMaxLevel(UpgradeType type) {
    final definition = definitionFor(type);
    return levelFor(type) >= definition.maxLevel;
  }

  bool canPurchase(UpgradeType type) {
    if (isMaxLevel(type)) {
      return false;
    }
    return dataManager.totalCoins >= costForNextLevel(type);
  }

  PlayerUpgradeModifiers get activeModifiers {
    final double handlingMultiplier = 1 + (dataManager.handlingLevel * 0.12);
    final double coinMagnetMultiplier =
        1 + (dataManager.coinMagnetLevel * 0.20);

    return PlayerUpgradeModifiers(
      handlingMultiplier: handlingMultiplier,
      coinMagnetRadiusMultiplier: coinMagnetMultiplier,
    );
  }

  Future<UpgradePurchaseResult> purchase(UpgradeType type) async {
    final definition = definitionFor(type);
    final currentLevel = levelFor(type);

    if (currentLevel >= definition.maxLevel) {
      return const UpgradePurchaseResult(
        success: false,
        message: 'Already at max level.',
      );
    }

    final int cost = definition.costForLevel(currentLevel);
    final bool paid = await dataManager.spendCoins(cost);
    if (!paid) {
      return const UpgradePurchaseResult(
        success: false,
        message: 'Not enough coins.',
      );
    }

    final int nextLevel = currentLevel + 1;
    switch (type) {
      case UpgradeType.handling:
        await dataManager.setHandlingLevel(nextLevel);
        break;
      case UpgradeType.coinMagnet:
        await dataManager.setCoinMagnetLevel(nextLevel);
        break;
    }

    return UpgradePurchaseResult(
      success: true,
      message: '${definition.title} upgraded to level $nextLevel.',
    );
  }
}