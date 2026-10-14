import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../data/demo.dart';
import 'api_client.dart';
import 'config.dart';
import 'entitlements.dart';

/// Pro passes bought in the app through Google Play (one-time products
/// `pro_7_days`, `pro_45_days`, `pro_100_days`; they never renew by
/// themselves). The server checks every purchase with Google, adds the pass
/// (after any pass still running) and consumes it, so the same pass can be
/// bought again later:
///
///   buy → Play sheet → purchaseStream → POST /v1/billing/google/verify
///       → completePurchase → Entitlements.refresh
///
/// [summary] is `GET /v1/billing`: the running pass, its dates, queued
/// passes and whether a longer pass exists (`canUpgrade`).
class BillingService extends ChangeNotifier {
  BillingService._();
  static final BillingService I = BillingService._();

  /// Play Billing exists only in the Android build with a server.
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android && AppConfig.hasApi;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<String, ProductDetails> _products = <String, ProductDetails>{};

  bool _storeReady = false;
  bool _loading = false;
  String _buying = ''; // product id while the Play sheet / verification runs
  bool _pending = false;
  String? _message;
  Map<String, dynamic> _summary = <String, dynamic>{};

  /// Google Play answered and the products are known.
  bool get storeReady => _storeReady;
  bool get loading => _loading;
  bool get busy => _buying.isNotEmpty;
  String get buying => _buying;

  /// A purchase is waiting for the payment to clear (e.g. cash / carrier).
  bool get pending => _pending;

  /// Last result to show once ('You're on Pro …' or an error); see [takeMessage].
  String? takeMessage() {
    final m = _message;
    _message = null;
    return m;
  }

  Map<String, dynamic> get summary => _summary;
  Map<String, dynamic> get current => _summary.m('current');
  bool get hasPass => current.isNotEmpty;
  bool get canUpgrade => _summary.b('canUpgrade');
  String get highestPassId => _summary.s('highestPassId');

  ProductDetails? product(String id) => _products[id];

  /// Listen for purchases from app start, so one that finished while the
  /// app was closed (or is still pending) is delivered and verified.
  void init() {
    if (!supported || _sub != null) return;
    _sub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) {
        _buying = '';
        _message = 'Google Play could not finish the purchase. Please try again.';
        notifyListeners();
      },
    );
  }

  /// Plans screen: products + the account's billing summary.
  Future<void> load(Iterable<String> productIds) async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    await Future.wait<void>(<Future<void>>[
      refreshSummary(),
      if (supported) _loadProducts(productIds),
    ]);
    _loading = false;
    notifyListeners();
  }

  Future<void> _loadProducts(Iterable<String> ids) async {
    try {
      final iap = InAppPurchase.instance;
      _storeReady = await iap.isAvailable();
      if (!_storeReady) return;
      final want = ids.where((x) => x.isNotEmpty).toSet();
      if (want.isNotEmpty) {
        final r = await iap.queryProductDetails(want);
        for (final p in r.productDetails) {
          _products[p.id] = p;
        }
      }
      // Purchases Play still holds (not yet verified / consumed) come back
      // through the stream as `restored`, and are verified again.
      if (ApiClient.signedIn) unawaited(iap.restorePurchases());
    } catch (_) {
      _storeReady = false;
    }
  }

  Future<void> refreshSummary() async {
    if (!AppConfig.hasApi || !ApiClient.signedIn) return;
    try {
      _summary = await ApiClient.get('/v1/billing');
      notifyListeners();
    } catch (_) {}
  }

  /// Opens the Google Play sheet for [productId]. Returns an error message
  /// when it can't open; the result arrives later through [takeMessage].
  Future<String?> buy(String productId) async {
    if (!supported) return 'Purchases aren’t available on this device.';
    if (!ApiClient.signedIn) return 'Sign in first to buy a pass.';
    if (busy) return null;
    final p = _products[productId];
    if (!_storeReady || p == null) return 'Google Play isn’t ready yet. Check your connection and try again.';
    if (_summary.s('playAccountId').isEmpty) await refreshSummary();
    _buying = productId;
    _message = null;
    notifyListeners();
    try {
      final ok = await InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(
          productDetails: p,
          // Ties the purchase to this account (server checks it).
          applicationUserName: _summary.s('playAccountId').isEmpty ? null : _summary.s('playAccountId'),
        ),
        autoConsume: false, // the server consumes after adding the pass
      );
      if (!ok) {
        _buying = '';
        notifyListeners();
        return 'Google Play could not open. Please try again.';
      }
      return null;
    } catch (e) {
      _buying = '';
      notifyListeners();
      return 'Google Play could not open. Please try again.';
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _pending = true;
          _message = 'Payment pending. Your pass starts as soon as Google Play confirms it.';
        case PurchaseStatus.canceled:
          if (_buying == p.productID) _buying = '';
          if (p.pendingCompletePurchase) await _complete(p);
        case PurchaseStatus.error:
          if (_buying == p.productID) _buying = '';
          _message = p.error?.message.isNotEmpty == true ? 'Google Play: ${p.error!.message}' : 'The purchase did not go through.';
          if (p.pendingCompletePurchase) await _complete(p);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verify(p);
      }
      notifyListeners();
    }
  }

  Future<void> _verify(PurchaseDetails p) async {
    final token = p.verificationData.serverVerificationData;
    if (token.isEmpty || !ApiClient.signedIn) return;
    try {
      final r = await ApiClient.postJson('/v1/billing/google/verify', <String, dynamic>{
        'productId': p.productID,
        'purchaseToken': token,
      });
      final billing = r.m('billing');
      if (billing.isNotEmpty) _summary = <String, dynamic>{..._summary, ...billing};
      if (r.s('status') == 'pending') {
        _pending = true;
        return; // Delivered again when it clears.
      }
      _pending = false;
      await _complete(p);
      if (_buying == p.productID || p.status == PurchaseStatus.purchased) {
        _message = 'You’re on Pro. Your pass is active.';
      }
      _buying = '';
      await Entitlements.I.refresh();
    } on ApiException catch (e) {
      if (_buying == p.productID) _buying = '';
      if (e.isNetwork) {
        // Not completed: Play keeps it and it is verified on the next open.
        _message = 'Your payment went through, but we couldn’t reach the server. Your pass will be added as soon as you’re back online.';
        return;
      }
      // Refused for good (other account, cancelled, already used): close it.
      await _complete(p);
      _message = e.message;
    }
  }

  Future<void> _complete(PurchaseDetails p) async {
    if (!p.pendingCompletePurchase) return;
    try {
      await InAppPurchase.instance.completePurchase(p);
    } catch (_) {
      // Already consumed by the server: nothing left to acknowledge.
    }
  }

  /// Signed out: forget the last account's summary.
  void clear() {
    _summary = <String, dynamic>{};
    _pending = false;
    _buying = '';
    _message = null;
    notifyListeners();
  }
}
