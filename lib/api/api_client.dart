import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/auth_token_store.dart';
import 'api_errors.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    AuthTokenStore? tokenStore,
    http.Client? httpClient,
  }) : _baseUri = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
       _tokenStore = tokenStore,
       _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final AuthTokenStore? _tokenStore;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> getJson(
    String path, {
    bool authenticated = false,
    Map<String, Object?>? queryParameters,
  }) async {
    final Object? decoded = await _send(
      'GET',
      path,
      authenticated: authenticated,
      queryParameters: queryParameters,
    );
    return _castJsonMap(decoded);
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    bool authenticated = false,
    Map<String, Object?>? queryParameters,
  }) async {
    final Object? decoded = await _send(
      'GET',
      path,
      authenticated: authenticated,
      queryParameters: queryParameters,
    );
    return _castJsonList(decoded);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    bool authenticated = false,
    Object? body,
  }) async {
    final Object? decoded = await _send(
      'POST',
      path,
      authenticated: authenticated,
      body: body,
    );
    return _castJsonMap(decoded);
  }

  void close() {
    _httpClient.close();
  }

  Future<Object?> _send(
    String method,
    String path, {
    bool authenticated = false,
    Map<String, Object?>? queryParameters,
    Object? body,
  }) async {
    final Uri uri = _buildUri(path, queryParameters);
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
    };
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    if (authenticated) {
      final String? token = await _tokenStore?.readToken();
      if (token == null || token.isEmpty) {
        throw const ApiUnauthorizedException();
      }
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final http.Response response = await _dispatch(
        method,
        uri,
        headers,
        body,
      ).timeout(const Duration(seconds: 10));
      return _decodeResponse(response);
    } on SocketException {
      throw const ApiNetworkException(
        'The shared service is unreachable right now. Check the network and try again.',
      );
    } on TimeoutException {
      throw const ApiNetworkException(
        'The shared service took too long to respond. Try again in a moment.',
      );
    } on http.ClientException catch (error) {
      throw ApiNetworkException(
        'The shared service request failed: ${error.message}',
      );
    }
  }

  Future<http.Response> _dispatch(
    String method,
    Uri uri,
    Map<String, String> headers,
    Object? body,
  ) {
    switch (method) {
      case 'GET':
        return _httpClient.get(uri, headers: headers);
      case 'POST':
        return _httpClient.post(
          uri,
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        );
      default:
        throw UnsupportedError('Unsupported HTTP method: $method');
    }
  }

  Uri _buildUri(String path, Map<String, Object?>? queryParameters) {
    final Uri resolved = _baseUri.resolve(
      path.startsWith('/') ? path.substring(1) : path,
    );
    if (queryParameters == null || queryParameters.isEmpty) {
      return resolved;
    }

    return resolved.replace(
      queryParameters: <String, String>{
        for (final MapEntry<String, Object?> entry in queryParameters.entries)
          if (entry.value != null) entry.key: entry.value.toString(),
      },
    );
  }

  Object? _decodeResponse(http.Response response) {
    final String rawBody = response.body.trim();
    final Object? decoded = rawBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(rawBody);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final String message =
        _extractErrorMessage(decoded) ??
        'The shared service returned HTTP ${response.statusCode}.';
    if (response.statusCode == 401) {
      throw ApiUnauthorizedException(message);
    }
    throw ApiRequestException(message, statusCode: response.statusCode);
  }

  String? _extractErrorMessage(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      final Object? detail =
          decoded['detail'] ?? decoded['message'] ?? decoded['error'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
    }
    return null;
  }

  Map<String, dynamic> _castJsonMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map<Object?, Object?>) {
      return value.cast<String, dynamic>();
    }
    throw const ApiRequestException(
      'The shared service returned an invalid JSON object.',
    );
  }

  List<dynamic> _castJsonList(Object? value) {
    if (value is List<dynamic>) {
      return value;
    }
    throw const ApiRequestException(
      'The shared service returned an invalid JSON list.',
    );
  }
}
