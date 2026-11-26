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

class ApiService {
  static const _timeout = Duration(seconds: 60); // Render free tier can take ~50s to wake up

  Future<dynamic> _req(String method, String path, {Object? body}) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final headers = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
    final uri = Uri.parse('$apiBaseUrl$path');
    try {
      final http.Response r = method == 'GET'
          ? await http.get(uri, headers: headers).timeout(_timeout)
          : await http.post(uri, headers: headers, body: jsonEncode(body ?? {})).timeout(_timeout);
      final data = r.body.isEmpty ? null : jsonDecode(r.body);
      if (r.statusCode >= 400) {
        throw ApiException(data is Map && data['error'] != null ? data['error'].toString() : 'Request failed (${r.statusCode})');
      }
      return data;
    } on TimeoutException {
      throw ApiException('The server is taking too long. Please try again.');
    } on SocketException {
      throw ApiException('No internet connection.');
    }
  }

  Future<Map<String, dynamic>> me() async => Map<String, dynamic>.from(await _req('GET', '/api/me'));
  Future<void> sessionStart() async => _req('POST', '/api/me/session-start');

  Future<List<Lot>> lots() async =>
      (await _req('GET', '/api/lots') as List).map((e) => Lot.fromJson(Map<String, dynamic>.from(e))).toList();

  Future<List<ParkSession>> sessions(String status, {String? lotId}) async {
    final q = 'status=$status${lotId != null ? '&lotId=$lotId' : ''}';
    return (await _req('GET', '/api/sessions?$q') as List).map((e) => ParkSession.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<String?> photo(String id) async => (await _req('GET', '/api/sessions/$id') as Map)['photo'] as String?;

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
  }) async {
    final r = await _req('POST', '/api/sessions/check-in', body: {
      'plate': plate,
      'size': size,
      if (lotId != null) 'lotId': lotId,
      if (ownerName != null && ownerName.isNotEmpty) 'ownerName': ownerName,
      if (ownerPhone != null && ownerPhone.isNotEmpty) 'ownerPhone': ownerPhone,
      if (photoBase64 != null) 'photoBase64': photoBase64,
      'plateSource': plateSource,
      if (detectedPlate != null) 'detectedPlate': detectedPlate,
      if (entryAt != null) 'entryAt': entryAt.toUtc().toIso8601String(),
    });
    return ParkSession.fromJson(Map<String, dynamic>.from(r));
  }

  Future<Quote> quote(String id) async => Quote.fromJson(Map<String, dynamic>.from(await _req('GET', '/api/sessions/$id/quote')));

  Future<Quote> checkOut(String id) async =>
      Quote.fromJson(Map<String, dynamic>.from(await _req('POST', '/api/sessions/$id/check-out')));
}
