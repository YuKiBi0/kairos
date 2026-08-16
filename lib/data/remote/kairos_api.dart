import 'package:dio/dio.dart';

import 'remote_models.dart';

class ApiFailure implements Exception {
  const ApiFailure({
    required this.code,
    required this.message,
    required this.statusCode,
    required this.retryable,
  });

  final String code;
  final String message;
  final int? statusCode;
  final bool retryable;

  @override
  String toString() => '$code: $message';
}

class KairosApi {
  KairosApi({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<RemoteSession> login({
    required Uri endpoint,
    required String username,
    required String password,
    required String deviceId,
    required String deviceName,
    required String platform,
  }) async {
    final json = await _request(
      endpoint: endpoint,
      method: 'POST',
      path: '/api/v1/auth/login',
      data: <String, Object?>{
        'username': username,
        'password': password,
        'device': <String, Object?>{
          'id': deviceId,
          'name': deviceName,
          'platform': platform,
        },
      },
    );
    return RemoteSession.fromJson(json, DateTime.now().toUtc());
  }

  Future<RemoteSession> refresh({
    required Uri endpoint,
    required String refreshToken,
  }) async {
    final json = await _request(
      endpoint: endpoint,
      method: 'POST',
      path: '/api/v1/auth/refresh',
      data: <String, Object?>{'refresh_token': refreshToken},
    );
    return RemoteSession.fromJson(json, DateTime.now().toUtc());
  }

  Future<void> logout({
    required Uri endpoint,
    required String refreshToken,
  }) async {
    await _request(
      endpoint: endpoint,
      method: 'POST',
      path: '/api/v1/auth/logout',
      data: <String, Object?>{'refresh_token': refreshToken},
      allowEmpty: true,
    );
  }

  Future<Map<String, dynamic>> snapshot({
    required Uri endpoint,
    required String accessToken,
  }) => _request(
    endpoint: endpoint,
    method: 'GET',
    path: '/api/v1/sync/snapshot',
    accessToken: accessToken,
  );

  Future<RemoteChangesPage> changes({
    required Uri endpoint,
    required String accessToken,
    required int after,
    int limit = 200,
  }) async {
    final json = await _request(
      endpoint: endpoint,
      method: 'GET',
      path: '/api/v1/sync/changes',
      accessToken: accessToken,
      query: <String, Object?>{'after': after, 'limit': limit},
    );
    return RemoteChangesPage(
      changes: (json['changes'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(RemoteChange.fromJson)
          .toList(growable: false),
      nextCursor: (json['next_cursor'] as num).toInt(),
      hasMore: json['has_more'] as bool,
    );
  }

  Future<List<PushResult>> push({
    required Uri endpoint,
    required String accessToken,
    required List<Map<String, Object?>> operations,
  }) async {
    final json = await _request(
      endpoint: endpoint,
      method: 'POST',
      path: '/api/v1/sync/push',
      accessToken: accessToken,
      data: <String, Object?>{'operations': operations},
    );
    return (json['results'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PushResult.fromJson)
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _request({
    required Uri endpoint,
    required String method,
    required String path,
    String? accessToken,
    Map<String, Object?>? data,
    Map<String, Object?>? query,
    bool allowEmpty = false,
  }) async {
    final base = endpoint.replace(
      path: endpoint.path == '/' ? '' : endpoint.path,
      query: '',
      fragment: '',
    );
    try {
      final response = await _dio.request<Object?>(
        base.resolve(path).toString(),
        data: data,
        queryParameters: query,
        options: Options(
          method: method,
          headers: <String, Object?>{
            'Accept': 'application/json',
            if (accessToken != null) 'Authorization': 'Bearer $accessToken',
          },
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json,
          sendTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      if (allowEmpty && response.data == null) {
        return const <String, dynamic>{};
      }
      final value = response.data;
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid server response.');
      }
      return value;
    } on DioException catch (error) {
      final response = error.response;
      final data = response?.data;
      String code = 'NETWORK_ERROR';
      String message = '无法连接同步服务';
      if (data is Map<String, dynamic>) {
        final envelope = data['error'];
        if (envelope is Map<String, dynamic>) {
          code = envelope['code'] as String? ?? code;
          message = envelope['message'] as String? ?? message;
        }
      }
      final status = response?.statusCode;
      throw ApiFailure(
        code: code,
        message: message,
        statusCode: status,
        retryable:
            status == null || status >= 500 || status == 408 || status == 429,
      );
    } on FormatException catch (error) {
      throw ApiFailure(
        code: 'INVALID_RESPONSE',
        message: error.message,
        statusCode: null,
        retryable: true,
      );
    }
  }
}
