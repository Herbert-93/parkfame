import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// No signal, a very slow connection, or the server still waking up.
/// Nothing is wrong with the request itself: keep it and try again later.
class OfflineException extends ApiException {
  OfflineException(super.message);
}

class ApiService {
  static const _timeout = Duration(seconds: 45); // slow mobile networks / Render free tier waking up
  static const _uploadTimeout = Duration(seconds: 120); // photo uploads on weak signal

  Future<dynamic> _req(String method, String path, {Object? body, Duration? timeout, int retries = 0}) async {
    var attempt = 0;
    while (true) {
      try {
        return await _once(method, path, body: body, timeout: timeout ?? _timeout);
      } on OfflineException {
        if (attempt >= retries) rethrow;
        attempt++;
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }
  }

  Future<dynamic> _once(String method, String path, {Object? body, required Duration timeout}) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
      final uri = Uri.parse('$apiBaseUrl$path');
      final http.Response r = method == 'GET'
          ? await http.get(uri, headers: headers).timeout(timeout)
          : await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(timeout);
      // gateway errors = the server is starting up / unreachable; an expired sign-in must not discard saved work
      if (r.statusCode == 502 || r.statusCode == 503 || r.statusCode == 504 || r.statusCode == 429) {
        throw OfflineException('The server is not reachable right now.');
      }
      if (r.statusCode == 401) throw OfflineException('Your sign-in needs refreshing. Check your connection.');
      dynamic data;
      try {
        data = r.body.isEmpty ? null : jsonDecode(r.body);
      } on FormatException {
        data = null;
      }
      if (r.statusCode >= 400) {
        throw ApiException(data is Map && data['error'] != null ? data['error'].toString() : 'Request failed (${r.statusCode})');
      }
      return data;
    } on TimeoutException {
      throw OfflineException('The connection is too slow right now.');
    } on SocketException {
      throw OfflineException('No internet connection.');
    } on HandshakeException {
      throw OfflineException('No stable internet connection.');
    } on http.ClientException {
      throw OfflineException('No internet connection.');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') throw OfflineException('No internet connection.');
      throw ApiException(e.message ?? 'Sign-in problem. Please sign in again.');
    }
  }

  Future<Map<String, dynamic>> me() async => Map<String, dynamic>.from(await _req('GET', '/api/me', retries: 2));
  Future<void> sessionStart() async => _req('POST', '/api/me/session-start');

  Future<List<dynamic>> lotsJson() async => (await _req('GET', '/api/lots', retries: 2)) as List;
  Future<List<Lot>> lots() async => (await lotsJson()).map((e) => Lot.fromJson(Map<String, dynamic>.from(e))).toList();

  Future<List<dynamic>> sessionsJson(String status, {String? lotId}) async {
    final q = 'status=$status${lotId != null ? '&lotId=$lotId' : ''}';
    return (await _req('GET', '/api/sessions?$q', retries: 2)) as List;
  }

  Future<List<ParkSession>> sessions(String status, {String? lotId}) async =>
      (await sessionsJson(status, lotId: lotId)).map((e) => ParkSession.fromJson(Map<String, dynamic>.from(e))).toList();

  Future<String?> photo(String id) async => (await _req('GET', '/api/sessions/$id', retries: 1) as Map)['photo'] as String?;

  /// `clientId` makes this safe to retry: the server keeps only the first copy.
  Future<ParkSession> checkIn({
    required String plate,
    required String size,
    String? lotId,
    String? ownerName,
    String? ownerPhone,
    String? photoBase64,
    required String plateSource,
    String? detectedPlate,
    DateTime? entryAt,
    String? clientId,
    DateTime? capturedAt,
  }) async {
    final r = await _req('POST', '/api/sessions/check-in', timeout: _uploadTimeout, body: {
      'plate': plate,
      'size': size,
      if (lotId != null) 'lotId': lotId,
      if (ownerName != null && ownerName.isNotEmpty) 'ownerName': ownerName,
      if (ownerPhone != null && ownerPhone.isNotEmpty) 'ownerPhone': ownerPhone,
      if (photoBase64 != null) 'photoBase64': photoBase64,
      'plateSource': plateSource,
      if (detectedPlate != null) 'detectedPlate': detectedPlate,
      if (entryAt != null) 'entryAt': entryAt.toUtc().toIso8601String(),
      if (clientId != null) 'clientId': clientId,
      if (capturedAt != null) 'capturedAt': capturedAt.toUtc().toIso8601String(),
    });
    return ParkSession.fromJson(Map<String, dynamic>.from(r));
  }

  Future<Quote> quote(String id) async => Quote.fromJson(Map<String, dynamic>.from(await _req('GET', '/api/sessions/$id/quote')));

  /// `exitAt` = the time the phone really collected the cash (only needed when sending late).
  Future<Quote> checkOut(String id, {DateTime? exitAt}) async => Quote.fromJson(Map<String, dynamic>.from(
      await _req('POST', '/api/sessions/$id/check-out', body: {if (exitAt != null) 'exitAt': exitAt.toUtc().toIso8601String()})));
}
