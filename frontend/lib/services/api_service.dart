import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/app_config.dart';
import 'storage_service.dart';

class ApiService {
  static final ApiService _i = ApiService._();

  factory ApiService() => _i;
  ApiService._();

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = await StorageService.getToken();
      if (token != null && token.isNotEmpty) {
        h['Authorization'] = 'Bearer $token';
      }
    }
    return h;
  }

  dynamic _parse(http.Response res) {
    if (res.statusCode >= 400) {
      dynamic body;
      try {
        body = jsonDecode(res.body);
      } catch (_) {
        throw 'Server error (${res.statusCode})';
      }
      final msg = body['message'];
      if (msg is List && msg.isNotEmpty) throw msg.first.toString();
      throw msg?.toString() ?? 'Error ${res.statusCode}';
    }
    if (res.body.isEmpty) return null;
    return jsonDecode(res.body);
  }

  MediaType? _guessMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
      return MediaType('image', 'jpeg');
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.bmp')) return MediaType('image', 'bmp');
    if (lower.endsWith('.heic')) return MediaType('image', 'heic');
    if (lower.endsWith('.heif')) return MediaType('image', 'heif');
    return null;
  }

  void _logApiDebug(String message) {
    final config = appConfig.toMap();
    debugPrint('🔵 API Debug: $message | Config: $config');
  }

  Future<void> _saveAuth(Map<String, dynamic> data) async {
    await StorageService.saveAuthData(
      token: data['access_token']?.toString() ?? '',
      userId: data['user']?['id']?.toString() ?? '',
      role: data['user']?['activeRole']?.toString() ?? 'worker',
      user: data['user'] as Map<String, dynamic>?,
    );
  }

  // AUTH
  Future<Map<String, dynamic>> signup({
    required String fullName,
    required String phoneNumber,
    required String password,
    String activeRole = 'worker',
    String? skills,
    String? city,
    String? country,
    double? lat,
    double? lon,
  }) async {
    final url = appConfig.endpoint('/users/signup');
    _logApiDebug('Signup attempt to: $url');
    final res = await http
        .post(
          Uri.parse(url),
          headers: await _headers(auth: false),
          body: jsonEncode({
            'fullName': fullName,
            'phoneNumber': phoneNumber,
            'password': password,
            'activeRole': activeRole,
            if (skills != null) 'skills': skills,
            if (city != null) 'city': city,
            if (country != null) 'country': country,
            if (lat != null) 'lat': lat,
            if (lon != null) 'lon': lon,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final data = _parse(res) as Map<String, dynamic>;
    await _saveAuth(data);
    return data;
  }

  Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String password,
  }) async {
    final url = appConfig.endpoint('/users/login');
    _logApiDebug('Login attempt to: $url');
    final res = await http
        .post(
          Uri.parse(url),
          headers: await _headers(auth: false),
          body: jsonEncode({
            'phoneNumber': phoneNumber,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final data = _parse(res) as Map<String, dynamic>;
    await _saveAuth(data);
    return data;
  }

  // PROFILE
  Future<Map<String, dynamic>> getMe() async {
    final res = await http
        .get(Uri.parse(appConfig.endpoint('/users/me')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _parse(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> updates) async {
    final res = await http
        .patch(
          Uri.parse(appConfig.endpoint('/users/me')),
          headers: await _headers(),
          body: jsonEncode(updates),
        )
        .timeout(const Duration(seconds: 15));
    return _parse(res) as Map<String, dynamic>;
  }

  // Avatar upload disabled — no-op returning empty URL
  Future<String> uploadAvatar(List<int> bytes, String filename) async {
    return '';
  }

  Future<Map<String, dynamic>> getUser(int id) async {
    final res = await http
        .get(Uri.parse(appConfig.endpoint('/users/$id')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _parse(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> switchRole() async {
    final res = await http
        .post(Uri.parse(appConfig.endpoint('/users/switch-role')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final data = _parse(res) as Map<String, dynamic>;
    if (data['token'] != null) {
      await StorageService.saveAuthData(
        token: data['token'].toString(),
        userId: (await StorageService.getUserId()) ?? '',
        role: data['activeRole'].toString(),
      );
    }
    return data;
  }

  Future<void> updateLocation(double lat, double lon) async {
    try {
      await http
          .post(
            Uri.parse(appConfig.endpoint('/users/location')),
            headers: await _headers(),
            body: jsonEncode({'lat': lat, 'lon': lon}),
          )
          .timeout(const Duration(seconds: 8));

      await http
          .post(
            Uri.parse(appConfig.aiEndpoint('/location')),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id':
                  int.tryParse((await StorageService.getUserId()) ?? '0'),
              'lat': lat,
              'lon': lon,
            }),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<void> markTutorialSeen() async {
    try {
      final res = await http
          .post(Uri.parse(appConfig.endpoint('/users/tutorial-seen')),
              headers: await _headers())
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        throw Exception('Failed to mark tutorial as seen: ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Warning: Error marking tutorial as seen: $e');
      rethrow;
    }
  }

  // JOBS
  Future<Map<String, dynamic>> createJob(Map<String, dynamic> data) async {
    final res = await http
        .post(Uri.parse(appConfig.endpoint('/jobs')),
            headers: await _headers(), body: jsonEncode(data))
        .timeout(const Duration(seconds: 15));
    return _parse(res) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMyJobs() async {
    final res = await http
        .get(Uri.parse(appConfig.endpoint('/jobs/mine')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final parsed = _parse(res);
    return parsed is List ? parsed : const [];
  }

  Future<List<dynamic>> getJobFeed() async {
    final res = await http
        .get(Uri.parse(appConfig.endpoint('/jobs/feed')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final parsed = _parse(res);
    return parsed is List ? parsed : const [];
  }

  Future<Map<String, dynamic>?> getActiveJob() async {
    final res = await http
        .get(Uri.parse(appConfig.endpoint('/jobs/active')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 404 || res.body == 'null') return null;
    return _parse(res) as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>> getJob(int id) async {
    final res = await http
        .get(Uri.parse(appConfig.endpoint('/jobs/$id')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _parse(res) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getBidsForJob(int jobId) async {
    final res = await http
        .get(Uri.parse(appConfig.endpoint('/jobs/$jobId/bids')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final parsed = _parse(res);
    return parsed is List ? parsed : const [];
  }

  Future<Map<String, dynamic>> placeBid(
    int jobId,
    double price, {
    String? message,
  }) async {
    final res = await http
        .post(
          Uri.parse(appConfig.endpoint('/jobs/$jobId/bids')),
          headers: await _headers(),
          body: jsonEncode(
              {'offeredPrice': price, if (message != null) 'message': message}),
        )
        .timeout(const Duration(seconds: 15));
    return _parse(res) as Map<String, dynamic>;
  }

  Future<void> rejectJob(int jobId) async {
    final res = await http
        .post(Uri.parse(appConfig.endpoint('/jobs/$jobId/reject')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    _parse(res);
  }

  Future<Map<String, dynamic>> acceptBid(int jobId, int bidId) async {
    final res = await http
        .post(Uri.parse(appConfig.endpoint('/jobs/$jobId/bids/$bidId/accept')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _parse(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptCounterBid(int jobId, int bidId) async {
    final res = await http
        .post(
            Uri.parse(
                appConfig.endpoint('/jobs/$jobId/bids/$bidId/counter/accept')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _parse(res) as Map<String, dynamic>;
  }

  Future<void> rejectCounterBid(int jobId, int bidId) async {
    final res = await http
        .post(
            Uri.parse(
                appConfig.endpoint('/jobs/$jobId/bids/$bidId/counter/reject')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    _parse(res);
  }

  Future<void> completeJob(int jobId) async {
    final res = await http
        .post(Uri.parse(appConfig.endpoint('/jobs/$jobId/complete')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    _parse(res);
  }

  Future<void> relistJob(int jobId) async {
    final res = await http
        .post(Uri.parse(appConfig.endpoint('/jobs/$jobId/relist')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    _parse(res);
  }

  // CHAT
  Future<List<dynamic>> getChatMessages(int jobId) async {
    final res = await http
        .get(Uri.parse(appConfig.endpoint('/chat/$jobId/messages')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final parsed = _parse(res);
    return parsed is List ? parsed : const [];
  }

  // REVIEWS
  Future<Map<String, dynamic>> submitReview({
    required int jobId,
    required int overallRating,
    int? workQualityRating,
    int? behaviorRating,
    int? smoothnessRating,
    String? comment,
    List<int>? beforeImageBytes,
    List<int>? afterImageBytes,
  }) async {
    final request = http.MultipartRequest(
        'POST', Uri.parse(appConfig.endpoint('/reviews')));
    request.headers.addAll(await _headers());
    request.headers.remove('Content-Type');

    request.fields['jobId'] = jobId.toString();
    request.fields['overallRating'] = overallRating.toString();
    if (workQualityRating != null)
      request.fields['workQualityRating'] = workQualityRating.toString();
    if (behaviorRating != null)
      request.fields['behaviorRating'] = behaviorRating.toString();
    if (smoothnessRating != null)
      request.fields['smoothnessRating'] = smoothnessRating.toString();
    if (comment != null && comment.trim().isNotEmpty)
      request.fields['comment'] = comment.trim();

    if (beforeImageBytes != null && beforeImageBytes.isNotEmpty) {
      request.files.add(http.MultipartFile.fromBytes(
        'beforeImage',
        beforeImageBytes,
        filename: 'review_before.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }
    if (afterImageBytes != null && afterImageBytes.isNotEmpty) {
      request.files.add(http.MultipartFile.fromBytes(
        'afterImage',
        afterImageBytes,
        filename: 'review_after.jpg',
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    return _parse(response) as Map<String, dynamic>;
  }

  Future<bool> hasReviewed(int jobId) async {
    final res = await http
        .get(Uri.parse(appConfig.endpoint('/reviews/check/$jobId')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _parse(res) == true;
  }

  Future<List<dynamic>> getUserReviews(int userId) async {
    final res = await http
        .get(Uri.parse(appConfig.endpoint('/reviews/user/$userId')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    final parsed = _parse(res);
    if (parsed is List) return parsed;
    if (parsed is Map<String, dynamic>) {
      final reviews = parsed['reviews'];
      if (reviews is List) return reviews;
    }
    return const [];
  }

  Future<Map<String, dynamic>> verifyReview(int reviewId) async {
    final res = await http
        .get(Uri.parse(appConfig.endpoint('/reviews/verify/$reviewId')),
            headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _parse(res) as Map<String, dynamic>;
  }

  // JOB STATUS / ACTIVITY
  Future<Map<String, dynamic>> updateJobStatus(int jobId, String status) async {
    final res = await http
        .patch(
          Uri.parse(appConfig.endpoint('/jobs/$jobId/status')),
          headers: await _headers(),
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 15));
    return _parse(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadImage(
      List<int> bytes, String filename) async {
    final request = http.MultipartRequest(
        'POST', Uri.parse(appConfig.endpoint('/jobs/upload-image')));
    request.headers.addAll(await _headers());
    request.headers.remove('Content-Type');
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: _guessMediaType(filename),
    ));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamed);
    return _parse(response) as Map<String, dynamic>;
  }

  // AI MATCHING
  Future<Map<String, dynamic>> matchWorkers({
    required String skill,
    required double lat,
    required double lon,
  }) async {
    final res = await http
        .post(
          Uri.parse(appConfig.aiEndpoint('/match')),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'skill': skill,
            'lat': lat,
            'lon': lon,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return _parse(res) as Map<String, dynamic>;
  }
}
