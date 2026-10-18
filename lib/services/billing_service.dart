import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../providers/settings_provider.dart';

enum BillingResultStatus {
  launchedStoreSheet,
  unlockedDebugFallback,
  storeUnavailable,
  productNotConfiguredInConsole,
  error,
}

class BillingState {
  final bool isStoreAvailable;
  final bool isLoading;
  final ProductDetails? proProduct;
  final String displayPrice;
  final String? errorMessage;

  const BillingState({
    this.isStoreAvailable = false,
    this.isLoading = false,
    this.proProduct,
    this.displayPrice = '4,99 €',
    this.errorMessage,
  });

  BillingState copyWith({
    bool? isStoreAvailable,
    bool? isLoading,
    ProductDetails? proProduct,
    String? displayPrice,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BillingState(
      isStoreAvailable: isStoreAvailable ?? this.isStoreAvailable,
      isLoading: isLoading ?? this.isLoading,
      proProduct: proProduct ?? this.proProduct,
      displayPrice: displayPrice ?? this.displayPrice,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final billingProvider = NotifierProvider<BillingNotifier, BillingState>(
  BillingNotifier.new,
);

class BillingNotifier extends Notifier<BillingState> {
  /// Exact Product ID (SKU) to create in Google Play Console > Monetize > In-app products
  static const String kLifetimeProProductId = 'sleepstop_lifetime_pro';

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  BillingState build() {
    _initBilling();
    ref.onDispose(() {
      _purchaseSubscription?.cancel();
    });
    return const BillingState();
  }

  Future<void> _initBilling() async {
    try {
      final iap = InAppPurchase.instance;
      final available = await iap.isAvailable();
      if (!available) {
        state = state.copyWith(isStoreAvailable: false);
        return;
      }

      _purchaseSubscription?.cancel();
      _purchaseSubscription = iap.purchaseStream.listen(
        _onPurchaseUpdated,
        onError: (_) {},
      );

      final response = await iap.queryProductDetails({kLifetimeProProductId});
      final product = response.productDetails.isNotEmpty
          ? response.productDetails.first
          : null;

      state = state.copyWith(
        isStoreAvailable: true,
        proProduct: product,
        displayPrice: product?.price ?? '4,99 €',
      );
    } catch (_) {
      state = state.copyWith(isStoreAvailable: false);
    }
  }

  Future<void> _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID != kLifetimeProProductId) continue;

      if (purchase.status == PurchaseStatus.pending) {
        state = state.copyWith(isLoading: true, clearError: true);
      } else if (purchase.status == PurchaseStatus.error) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: purchase.error?.message,
        );
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Mandatory on Google Play: acknowledge/complete the purchase within 3 days
        if (purchase.pendingCompletePurchase) {
          try {
            await InAppPurchase.instance.completePurchase(purchase);
          } catch (_) {}
        }
        await ref.read(settingsProvider.notifier).setProUnlocked(true);
        state = state.copyWith(isLoading: false, clearError: true);
      } else if (purchase.status == PurchaseStatus.canceled) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<BillingResultStatus> buyLifetimePro() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final iap = InAppPurchase.instance;
      final available = await iap.isAvailable();

      if (available) {
        ProductDetails? product = state.proProduct;
        if (product == null) {
          final response = await iap.queryProductDetails({
            kLifetimeProProductId,
          });
          if (response.productDetails.isNotEmpty) {
            product = response.productDetails.first;
            state = state.copyWith(
              proProduct: product,
              displayPrice: product.price,
            );
          }
        }

        if (product != null) {
          final param = PurchaseParam(productDetails: product);
          await iap.buyNonConsumable(purchaseParam: param);
          state = state.copyWith(isLoading: false);
          return BillingResultStatus.launchedStoreSheet;
        }
      }

      // If running in debug mode before the SKU is created in Google Play Console,
      // allow unlocking locally for testing.
      if (kDebugMode) {
        await ref.read(settingsProvider.notifier).setProUnlocked(true);
        state = state.copyWith(isLoading: false);
        return BillingResultStatus.unlockedDebugFallback;
      }

      state = state.copyWith(isLoading: false);
      return BillingResultStatus.productNotConfiguredInConsole;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return BillingResultStatus.error;
    }
  }

  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final iap = InAppPurchase.instance;
      if (await iap.isAvailable()) {
        await iap.restorePurchases();
      } else if (kDebugMode) {
        await ref.read(settingsProvider.notifier).setProUnlocked(true);
      }
    } catch (_) {
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}
