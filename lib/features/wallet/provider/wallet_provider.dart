import 'package:flutter/material.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../models/ledger_model.dart';
import '../../../models/package_model.dart';
import '../../../models/payment_method_model.dart';
import '../../../models/topup_model.dart';
import '../data/wallet_api.dart';

class WalletProvider extends ChangeNotifier {
  late final WalletApi api;

  WalletProvider({
    required ApiClient apiClient,
  }) {
    api = WalletApi(apiClient);
  }

  bool loading = false;
  bool submitting = false;
  String? error;

  List<PackageModel> packages = [];
  List<PaymentMethodModel> paymentMethods = [];
  List<TopupModel> topups = [];
  List<LedgerModel> ledger = [];

  Future<void> loadWallet() async {
    _setLoading(true);

    try {
      final result = await Future.wait([
        api.getPackages(),
        api.getPaymentMethods(),
        api.getTopups(),
        api.getLedger(),
      ]);

      packages = result[0] as List<PackageModel>;
      paymentMethods = result[1] as List<PaymentMethodModel>;
      topups = result[2] as List<TopupModel>;
      ledger = result[3] as List<LedgerModel>;

      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل المحفظة';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadPackages() async {
    _setLoading(true);

    try {
      packages = await api.getPackages();
      paymentMethods = await api.getPaymentMethods();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل الباقات';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTopups({bool silent = false}) async {
    if (!silent) _setLoading(true);

    try {
      topups = await api.getTopups();
      error = null;
      if (silent) notifyListeners();
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل طلبات الشحن';
      if (silent) notifyListeners();
    } finally {
      if (!silent) _setLoading(false);
    }
  }

  /// تحديث صامت كامل للمحفظة (رصيد/سجل/شحن) عند استلام حدث من السيرفر.
  Future<void> refreshSilent() async {
    try {
      final result = await Future.wait([
        api.getTopups(),
        api.getLedger(),
      ]);
      topups = result[0] as List<TopupModel>;
      ledger = result[1] as List<LedgerModel>;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadLedger() async {
    _setLoading(true);

    try {
      ledger = await api.getLedger();
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر تحميل سجل العمليات';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> submitTopup({
    required int packageId,
    required String receiptPath,
  }) async {
    submitting = true;
    error = null;
    notifyListeners();

    try {
      final topup = await api.createTopup(
        packageId: packageId,
        receiptPath: receiptPath,
      );

      topups.insert(0, topup);
      error = null;
    } catch (e) {
      error = e is ApiException ? e.message : 'تعذر إرسال طلب الشحن';
      rethrow;
    } finally {
      submitting = false;
      notifyListeners();
    }
  }

  PaymentMethodModel? get firstPaymentMethod {
    if (paymentMethods.isEmpty) return null;
    return paymentMethods.first;
  }

  int get pendingTopups {
    return topups.where((e) => e.isPending).length;
  }

  void _setLoading(bool value) {
    loading = value;
    notifyListeners();
  }
}