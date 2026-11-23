import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'models.dart';
import 'utils.dart';

class AppState extends ChangeNotifier {
  final api = ApiService();
  Map<String, dynamic>? me;
  Lot? lot;
  List<ParkSession> parked = [];
  List<ParkSession> history = [];
  bool loading = false;
  String? error;
  Timer? _timer;

  String get name => (me?['name'] ?? '') as String;
  String get email => (me?['email'] ?? '') as String;
  String get role => (me?['role'] ?? '') as String;

  num get collectedToday =>
      history.where((s) => s.exitAt != null && isToday(s.exitAt!)).fold<num>(0, (a, s) => a + (s.amount ?? 0));
  int get checkOutsToday => history.where((s) => s.exitAt != null && isToday(s.exitAt!)).length;

  Future<void> bootstrap() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      me = await api.me();
      unawaited(api.sessionStart().catchError((_) {}));
      final lots = await api.lots();
      if (lots.isEmpty) throw ApiException('No parking lot is assigned to your account. Ask your admin.');
      lot = lots.firstWhere((l) => l.id == me?['lotId'], orElse: () => lots.first);
      await refresh();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (lot == null) return;
    try {
      final r = await Future.wait([api.sessions('parked', lotId: lot!.id), api.sessions('exited', lotId: lot!.id)]);
      parked = r[0];
      history = r[1];
      error = null;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  void reset() {
    _timer?.cancel();
    me = null;
    lot = null;
    parked = [];
    history = [];
    error = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
