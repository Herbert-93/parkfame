import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'models.dart';
import 'offline.dart';
import 'utils.dart';

/// What happened when a car was checked out.
class CheckoutOutcome {
  final Quote quote;
  final bool sent; // false = saved on the phone, will be sent when the connection is back
  CheckoutOutcome(this.quote, this.sent);
}

class AppState extends ChangeNotifier {
  final api = ApiService();
  Map<String, dynamic>? me;
  Lot? lot;

  List<ParkSession> _serverParked = [];
  List<ParkSession> _serverHistory = [];
  List<PendingOp> pending = []; // saved on this phone, waiting to be sent
  Map<String, String> rejectedMsgs = {}; // things the server refused when they were finally sent

  bool offline = false; // true when the last attempt to reach the server failed
  bool syncing = false;
  bool loading = false;
  String? error;
  Timer? _timer;
  bool _refreshing = false;

  String get name => (me?['name'] ?? '') as String;
  String get email => (me?['email'] ?? '') as String;
  String get role => (me?['role'] ?? '') as String;
  int get pendingCount => pending.length;
  List<String> get rejected => rejectedMsgs.values.toList();

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'anon';
  String _k(String n) => '${_uid}_$n';
  String _photoName(PendingOp o) => _k('photo_${o.id}.jpg');

  // ---- what the screens show: server data + things still waiting on this phone -------------------------------
  List<ParkSession> get _localCheckIns => [
        for (final o in pending)
          if (o.type == 'checkin' && lot != null && !_serverParked.any((s) => s.id == o.sessionId)) _localSession(o),
      ];

  List<ParkSession> get parked {
    final leaving = {for (final o in pending) if (o.type == 'checkout') o.data['sessionId'] as String};
    return [..._localCheckIns, ..._serverParked].where((s) => !leaving.contains(s.id)).toList();
  }

  List<ParkSession> get history {
    final all = [..._localCheckIns, ..._serverParked];
    final out = <ParkSession>[];
    final seen = <String>{};
    for (final o in pending.reversed) {
      if (o.type != 'checkout') continue;
      final id = o.data['sessionId'] as String;
      final base = all.where((s) => s.id == id);
      if (base.isEmpty) continue;
      out.add(base.first.asExited(
        exitAt: DateTime.parse(o.data['exitAt'] as String).toLocal(),
        amount: o.data['amount'] as num,
        minutes: (o.data['minutes'] as num).toInt(),
      ));
      seen.add(id);
    }
    for (final h in _serverHistory) {
      if (!seen.contains(h.id)) out.add(h);
    }
    return out;
  }

  num get collectedToday => history.where((s) => s.exitAt != null && isToday(s.exitAt!)).fold<num>(0, (a, s) => a + (s.amount ?? 0));
  int get checkOutsToday => history.where((s) => s.exitAt != null && isToday(s.exitAt!)).length;

  ParkSession _localSession(PendingOp o) {
    final d = o.data;
    return ParkSession(
      id: o.sessionId,
      lotId: d['lotId'] as String,
      plate: o.plate,
      size: d['size'] as String,
      status: 'parked',
      entryAt: DateTime.parse((d['entryAt'] ?? d['capturedAt']) as String).toLocal(),
      ownerName: d['ownerName'] as String?,
      ownerPhone: d['ownerPhone'] as String?,
      hasPhoto: true,
      rates: lot!.rates,
      pending: true,
    );
  }

  // ---- start up ---------------------------------------------------------------------------------------------
  Future<void> bootstrap() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      try {
        me = await api.me();
        await LocalStore.writeJson(_k('me.json'), me!);
        unawaited(api.sessionStart().catchError((_) {}));
      } on OfflineException {
        final c = await LocalStore.readJson(_k('me.json'));
        if (c == null) rethrow; // never opened with internet on this phone yet
        me = Map<String, dynamic>.from(c as Map);
        offline = true;
      }

      List<dynamic> lotsJson;
      try {
        lotsJson = await api.lotsJson();
        await LocalStore.writeJson(_k('lots.json'), lotsJson);
      } on OfflineException {
        final c = await LocalStore.readJson(_k('lots.json'));
        if (c == null) rethrow;
        lotsJson = c as List;
        offline = true;
      }
      final lots = lotsJson.map((e) => Lot.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (lots.isEmpty) throw ApiException('No parking lot is assigned to your account. Ask your admin.');
      lot = lots.firstWhere((l) => l.id == me?['lotId'], orElse: () => lots.first);

      await _loadQueue();
      await _loadCache();
      notifyListeners(); // show saved data straight away, then update it
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
    if (lot == null || _refreshing) return;
    _refreshing = true;
    try {
      await syncPending();
      try {
        final r = await Future.wait([api.sessionsJson('parked', lotId: lot!.id), api.sessionsJson('exited', lotId: lot!.id)]);
        _serverParked = _parse(r[0]);
        _serverHistory = _parse(r[1]);
        offline = false;
        error = null;
        await LocalStore.writeJson(_k('parked.json'), r[0]);
        await LocalStore.writeJson(_k('history.json'), r[1]);
      } on OfflineException {
        offline = true; // keep showing the last saved data
        error = null;
      } catch (e) {
        error = e.toString();
      }
    } finally {
      _refreshing = false;
    }
    notifyListeners();
  }

  List<ParkSession> _parse(List<dynamic> raw) => raw.map((e) => ParkSession.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  Future<void> _loadCache() async {
    final p = await LocalStore.readJson(_k('parked.json'));
    final h = await LocalStore.readJson(_k('history.json'));
    if (_serverParked.isEmpty && p is List) _serverParked = _parse(p);
    if (_serverHistory.isEmpty && h is List) _serverHistory = _parse(h);
  }

  // ---- the send-later queue ---------------------------------------------------------------------------------
  Future<void> _loadQueue() async {
    final q = await LocalStore.readJson(_k('queue.json'));
    pending = q is List ? q.map((e) => PendingOp.fromJson(Map<String, dynamic>.from(e as Map))).toList() : [];
    final r = await LocalStore.readJson(_k('rejected.json'));
    rejectedMsgs = r is Map ? r.map((k, v) => MapEntry(k as String, v.toString())) : {};
  }

  Future<void> _saveQueue() async {
    await LocalStore.writeJson(_k('queue.json'), pending.map((o) => o.toJson()).toList());
    await LocalStore.writeJson(_k('rejected.json'), rejectedMsgs);
  }

  Future<void> _send(PendingOp op) async {
    final d = op.data;
    if (op.type == 'checkin') {
      final bytes = await LocalStore.readBytes(_photoName(op));
      if (bytes == null) throw ApiException('The saved photo is missing.');
      await api.checkIn(
        plate: d['plate'] as String,
        size: d['size'] as String,
        lotId: d['lotId'] as String,
        ownerName: d['ownerName'] as String?,
        ownerPhone: d['ownerPhone'] as String?,
        photoBase64: base64Encode(bytes),
        plateSource: d['plateSource'] as String,
        detectedPlate: d['detectedPlate'] as String?,
        entryAt: d['entryAt'] == null ? null : DateTime.parse(d['entryAt'] as String),
        clientId: op.id,
        capturedAt: DateTime.parse(d['capturedAt'] as String),
      );
    } else {
      await api.checkOut(d['sessionId'] as String, exitAt: DateTime.parse(d['exitAt'] as String));
    }
  }

  /// Sends everything saved on the phone, oldest first. Stops quietly when there is still no connection.
  Future<void> syncPending() async {
    if (syncing || pending.isEmpty) return;
    syncing = true;
    notifyListeners();
    try {
      while (pending.isNotEmpty) {
        final op = pending.first;
        try {
          await _send(op);
        } on OfflineException {
          break; // still no (usable) connection: try again later, nothing is lost
        } on ApiException catch (e) {
          final already = op.type == 'checkout' && e.message.contains('already been checked out');
          if (!already) {
            final what = op.type == 'checkin' ? 'Check-in' : 'Check-out';
            rejectedMsgs[op.id] = '$what of ${op.plate} was not accepted: ${e.message}';
          }
        } catch (e) {
          rejectedMsgs[op.id] = '${op.type == 'checkin' ? 'Check-in' : 'Check-out'} of ${op.plate} could not be sent: $e';
        }
        pending.removeAt(0);
        await LocalStore.delete(_photoName(op));
        await _saveQueue();
        notifyListeners();
      }
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  void dismissRejected() {
    rejectedMsgs = {};
    _saveQueue();
    notifyListeners();
  }

  // ---- actions used by the screens --------------------------------------------------------------------------
  /// Saves the check-in on the phone first (nothing can be lost), then tries to send it.
  /// Returns true if the server has it, false if it is saved and will be sent when the signal is back.
  /// Throws if the server refuses it (e.g. the plate is already parked).
  Future<bool> submitCheckIn({
    required String plate,
    required String size,
    String? ownerName,
    String? ownerPhone,
    required Uint8List photo,
    required String plateSource,
    String? detectedPlate,
    DateTime? entryAt,
  }) async {
    final op = PendingOp(newClientId(), 'checkin', {
      'plate': plate,
      'size': size,
      'lotId': lot!.id,
      'ownerName': (ownerName ?? '').isEmpty ? null : ownerName,
      'ownerPhone': (ownerPhone ?? '').isEmpty ? null : ownerPhone,
      'plateSource': plateSource,
      'detectedPlate': detectedPlate,
      'entryAt': entryAt?.toUtc().toIso8601String(),
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
    });
    await LocalStore.writeBytes(_photoName(op), photo);
    pending.add(op);
    await _saveQueue();
    notifyListeners();

    // wait a little for the server; on a weak connection the sending carries on in the background
    await syncPending().timeout(const Duration(seconds: 25), onTimeout: () {});
    final refused = rejectedMsgs.remove(op.id);
    if (refused != null) {
      await _saveQueue();
      notifyListeners();
      throw ApiException(refused.replaceFirst(RegExp(r'^Check-in of \w+ was not accepted: '), ''));
    }
    final sent = !pending.any((o) => o.id == op.id);
    if (sent) unawaited(refresh());
    return sent;
  }

  /// A price quote that needs no internet.
  Quote localQuote(ParkSession s) => calcQuote(s.entryAt, DateTime.now(), s.size, s.rates ?? lot!.rates);

  /// Checks a car out. With a connection it is recorded straight away; without one the amount is worked out
  /// on the phone and the check-out is sent later with the real time.
  Future<CheckoutOutcome> checkOut(ParkSession s) async {
    if (pending.isEmpty && !s.pending) {
      try {
        // on a weak connection do not make the attendant wait long: after 20s it is saved on the phone instead
        final q = await api.checkOut(s.id).timeout(const Duration(seconds: 20));
        await refresh();
        return CheckoutOutcome(q, true);
      } on OfflineException {
        // fall through: save it on the phone
      } on TimeoutException {
        // fall through (if the server did get it, the later send is ignored as "already checked out")
      }
    }
    final now = DateTime.now();
    final q = calcQuote(s.entryAt, now, s.size, s.rates ?? lot!.rates);
    pending.add(PendingOp(newClientId(), 'checkout', {
      'sessionId': s.id,
      'plate': s.plate,
      'exitAt': now.toUtc().toIso8601String(),
      'amount': q.amount,
      'minutes': q.minutes,
    }));
    await _saveQueue();
    notifyListeners();
    await syncPending().timeout(const Duration(seconds: 25), onTimeout: () {});
    return CheckoutOutcome(q, pending.isEmpty);
  }

  /// The plate photo of a check-in that is still waiting on this phone.
  Future<String?> localPhoto(ParkSession s) async {
    for (final o in pending) {
      if (o.type == 'checkin' && o.sessionId == s.id) {
        final b = await LocalStore.readBytes(_photoName(o));
        return b == null ? null : base64Encode(b);
      }
    }
    return null;
  }

  void reset() {
    _timer?.cancel();
    me = null;
    lot = null;
    _serverParked = [];
    _serverHistory = [];
    pending = [];
    rejectedMsgs = {};
    offline = false;
    error = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
