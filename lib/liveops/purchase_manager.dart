import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../meta/data_manager.dart';
import 'analytics_manager.dart';

class PurchaseCatalog {
  static const String removeAds = 'remove_ads';
  static const String coinPackSmall = 'coin_pack_small';
  static const String coinPackLarge = 'coin_pack_large';

  static const Set<String> all = {
    removeAds,
    coinPackSmall,
    coinPackLarge,
  };
}

class PurchaseManager {
  PurchaseManager({
    required this.dataManager,
    required this.analyticsManager,
  });

  final DataManager dataManager;
  final AnalyticsManager analyticsManager;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool _available = false;
  bool _initialized = false;
  final Map<String, ProductDetails> _products = <String, ProductDetails>{};

  bool get isAvailable => _available;
  bool get isRemoveAdsPurchased => dataManager.removeAdsPurchased;

  ProductDetails? productFor(String productId) => _products[productId];

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      _available = await _iap.isAvailable();
      if (!_available) {
        _initialized = true;
        return;
      }

      final response = await _iap.queryProductDetails(PurchaseCatalog.all);
      for (final product in response.productDetails) {
        _products[product.id] = product;
      }

      _purchaseSubscription = _iap.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () {
          _purchaseSubscription?.cancel();
        },
        onError: (_) {
          // Purchase stream errors should never crash the game.
        },
      );

      _initialized = true;
    } catch (e) {
      print('PurchaseManager initialization failed: $e');
      _initialized = true;
    }
  }

  Future<bool> buyProduct(String productId) async {
    if (!_available) {
      return false;
    }

    final product = _products[productId];
    if (product == null) {
      return false;
    }

    final param = PurchaseParam(productDetails: product);
    try {
      if (productId == PurchaseCatalog.removeAds) {
        return _iap.buyNonConsumable(purchaseParam: param);
      }

      return _iap.buyConsumable(
        purchaseParam: param,
        autoConsume: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> restorePurchases() async {
    if (!_available) {
      return;
    }
    try {
      await _iap.restorePurchases();
    } catch (_) {
      // Ignore restore failures and keep gameplay running.
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          break;
        case PurchaseStatus.canceled:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _deliverPurchaseIfValid(purchase);
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _deliverPurchaseIfValid(PurchaseDetails purchase) async {
    if (!PurchaseCatalog.all.contains(purchase.productID)) {
      return;
    }

    // Client-side allowlist validation. Replace with server validation in prod.
    switch (purchase.productID) {
      case PurchaseCatalog.removeAds:
        await dataManager.setRemoveAdsPurchased(true);
        await analyticsManager.trackPurchase(
          productId: purchase.productID,
          purchaseType: 'non_consumable',
        );
        break;
      case PurchaseCatalog.coinPackSmall:
        await dataManager.addCoins(250);
        await analyticsManager.trackPurchase(
          productId: purchase.productID,
          purchaseType: 'consumable',
        );
        break;
      case PurchaseCatalog.coinPackLarge:
        await dataManager.addCoins(700);
        await analyticsManager.trackPurchase(
          productId: purchase.productID,
          purchaseType: 'consumable',
        );
        break;
    }
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
  }
}
