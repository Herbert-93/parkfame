import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'models.dart';

/// Tiny storage inside the app's private folder: saved data + photos that are waiting to be sent.
class LocalStore {
  static Directory? _dir;

  static Future<Directory> _root() async {
    final existing = _dir;
    if (existing != null) return existing;
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/parkfame');
    if (!await d.exists()) await d.create(recursive: true);
    _dir = d;
    return d;
  }

  static Future<File> _file(String name) async => File('${(await _root()).path}/$name');

  static Future<void> writeJson(String name, Object data) async {
    final f = await _file(name);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(f.path);
  }

  static Future<dynamic> readJson(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeBytes(String name, List<int> bytes) async {
    final f = await _file(name);
    await f.writeAsBytes(bytes, flush: true);
  }

  static Future<List<int>?> readBytes(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<void> delete(String name) async {
    try {
      final f = await _file(name);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

/// A random id for one action. The server uses it to ignore duplicates, so retrying is always safe.
String newClientId() {
  final r = math.Random.secure();
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(20, (_) => chars[r.nextInt(chars.length)]).join();
}

/// A check-in or check-out saved on the phone, waiting for a connection.
class PendingOp {
  final String id; // client id
  final String type; // 'checkin' | 'checkout'
  final Map<String, dynamic> data;
  PendingOp(this.id, this.type, this.data);

  /// The server stores a check-in under this id, so the phone and server agree on it.
  String get sessionId => type == 'checkin' ? 'c_$id' : data['sessionId'] as String;
  String get plate => (data['plate'] ?? '') as String;

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'data': data};
  factory PendingOp.fromJson(Map<String, dynamic> j) =>
      PendingOp(j['id'] as String, j['type'] as String, Map<String, dynamic>.from(j['data'] as Map));
}

/// Same billing rules as the server (backend/src/billing.ts), so the phone can quote a price without internet.
Quote calcQuote(DateTime entry, DateTime exit, String size, RateConfig cfg) {
  final ms = exit.millisecondsSinceEpoch - entry.millisecondsSinceEpoch;
  final minutes = ms <= 0 ? 0 : (ms / 60000).ceil();
  final rate = cfg.sizes[size]!.ratePerBlock;
  final blockMin = cfg.blockHours * 60;
  final windowMin = (cfg.overstayHours * 60).round();
  DateTime at(int m) => entry.add(Duration(minutes: m));

  if (minutes <= cfg.graceMinutes) return Quote(minutes, 0, rate, 0, at(cfg.graceMinutes));

  final int stdBlocks = 1 + math.max<int>(0, ((minutes - windowMin) / blockMin).ceil() - 1);

  if (cfg.longStayDays > 0) {
    final int stdMax = ((cfg.longStayDays * 1440) / blockMin).ceil();
    final int paidUntil = stdMax * blockMin;
    final int longMin = cfg.longStayBlockHours * 60;
    final int blocksStd = math.min<int>(stdBlocks, stdMax);
    final int longBlocks = minutes > paidUntil + windowMin ? ((minutes - paidUntil - windowMin) / longMin).ceil() : 0;
    final int blocks = blocksStd + longBlocks;
    final int next = blocksStd >= stdMax ? paidUntil + windowMin + longBlocks * longMin : blocksStd * blockMin + windowMin;
    return Quote(minutes, blocks, rate, blocks * rate, at(next));
  }
  return Quote(minutes, stdBlocks, rate, stdBlocks * rate, at(stdBlocks * blockMin + windowMin));
}
