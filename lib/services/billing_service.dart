import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../providers/settings_provider.dart';
import 'telemetry_service.dart';

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
    this.displayPrice = '9,99 €',
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
  static const String _firestoreBase =
      'https://firestore.googleapis.com/v1/projects/sleepstop-eu/databases/(default)/documents';

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
    unawaited(_verifyActiveVipCodeStatus());
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
        displayPrice: product?.price ?? '9,99 €',
      );
    } catch (_) {
      state = state.copyWith(isStoreAvailable: false);
    }
  }

  /// Checks if a previously redeemed VIP code was deleted or suspended in the Admin Console.
  Future<void> _verifyActiveVipCodeStatus() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final settings = ref.read(settingsProvider);
    final vipCode = settings.redeemedVipCode;
    if (!settings.isProUnlocked || vipCode == null || vipCode.isEmpty) return;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse('$_firestoreBase/vip_codes/$vipCode');
      final req = await client.getUrl(uri);
      final resp = await req.close().timeout(const Duration(seconds: 4));
      if (resp.statusCode == 404) {
        // Code was deleted by Admin -> revoke VIP unlock
        await ref
            .read(settingsProvider.notifier)
            .setProUnlocked(false, clearVipCode: true);
      } else if (resp.statusCode == 200) {
        final body = await resp.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final fields = data['fields'] as Map<String, dynamic>?;
        final active =
            (fields?['active'] as Map<String, dynamic>?)?['booleanValue']
                as bool? ??
            true;
        if (!active) {
          await ref
              .read(settingsProvider.notifier)
              .setProUnlocked(false, clearVipCode: true);
        }
      }
    } catch (_) {
      // Offline: keep existing unlock
    } finally {
      client.close();
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
        if (purchase.pendingCompletePurchase) {
          try {
            await InAppPurchase.instance.completePurchase(purchase);
          } catch (_) {}
        }
        final settings = ref.read(settingsProvider);
        if (!settings.isProUnlocked) {
          unawaited(
            TelemetryService.instance.recordProUnlocked(
              enabled: settings.anonymousTelemetryEnabled,
              languageCode: settings.languageCode,
              isVipCode: false,
            ),
          );
        }
        await ref
            .read(settingsProvider.notifier)
            .setProUnlocked(true, clearVipCode: true);
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

      if (kDebugMode) {
        final settings = ref.read(settingsProvider);
        unawaited(
          TelemetryService.instance.recordProUnlocked(
            enabled: settings.anonymousTelemetryEnabled,
            languageCode: settings.languageCode,
            isVipCode: false,
          ),
        );
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

  static String computeVipSignature(String seed4) {
    const salt = 'SLEEPSTOP_LUDO_2026_VIP';
    final input = '${seed4.toUpperCase()}:$salt';
    int hash = 5381;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash * 33) ^ input.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return (hash % 1679616).toRadixString(36).toUpperCase().padLeft(4, '0');
  }

  Future<bool> verifyAndRedeemVipCode(String rawCode) async {
    final cleaned = rawCode.trim().toUpperCase();
    final parts = cleaned.split('-');
    if (parts.length != 4 ||
        parts[0] != 'SS' ||
        parts[1] != 'VIP' ||
        parts[2].length != 4 ||
        parts[3].length != 4) {
      return false;
    }

    final expectedSig = computeVipSignature(parts[2]);
    if (parts[3] != expectedSig) {
      return false;
    }

    // The signature above is only a cheap format check (the salt ships in the
    // APK). The real gate is Firestore: the code must exist AND be active.
    // No offline fallback: without network, redemption is refused.
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);
    try {
      final getUri = Uri.parse('$_firestoreBase/vip_codes/$cleaned');
      final getReq = await client.getUrl(getUri);
      final getResp = await getReq.close().timeout(const Duration(seconds: 6));

      if (getResp.statusCode != 200) {
        // 404 = deleted or never issued; anything else = refuse rather than trust.
        return false;
      }

      final body = await getResp.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final fields = data['fields'] as Map<String, dynamic>?;
      final active =
          (fields?['active'] as Map<String, dynamic>?)?['booleanValue']
              as bool? ??
          false;
      if (!active) {
        return false;
      }

      // Increment usesCount and set lastUsedAt in Firestore (the security
      // rules only allow exactly +1 on these two fields for anonymous writes).
      final commitUri = Uri.parse('$_firestoreBase:commit');
      final commitReq = await client.postUrl(commitUri);
      commitReq.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      final commitPayload = jsonEncode({
        'writes': [
          {
            'transform': {
              'document':
                  'projects/sleepstop-eu/databases/(default)/documents/vip_codes/$cleaned',
              'fieldTransforms': [
                {
                  'fieldPath': 'usesCount',
                  'increment': {'integerValue': '1'},
                },
                {
                  'fieldPath': 'lastUsedAt',
                  'setToServerValue': 'REQUEST_TIME',
                },
              ],
            },
          },
        ],
      });
      commitReq.add(utf8.encode(commitPayload));
      final commitResp = await commitReq.close().timeout(
        const Duration(seconds: 6),
      );
      await commitResp.drain<void>();
    } catch (_) {
      // Offline or Firestore unreachable: refuse (user can retry when online).
      return false;
    } finally {
      client.close();
    }

    final settings = ref.read(settingsProvider);
    unawaited(
      TelemetryService.instance.recordProUnlocked(
        enabled: settings.anonymousTelemetryEnabled,
        languageCode: settings.languageCode,
        isVipCode: true,
      ),
    );
    await ref
        .read(settingsProvider.notifier)
        .setProUnlocked(true, vipCode: cleaned);
    return true;
  }
}
