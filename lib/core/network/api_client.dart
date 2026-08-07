import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../storage/local_storage.dart';
import '../utils/app_toast.dart';

class ApiClient {
  static const String _productionUrl = 'https://api.academypro.co.za';
  
  static const String _activeBaseUrl = _productionUrl;
  static String get baseUrl => _activeBaseUrl;

  late final Dio dio;

  ApiClient() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = LocalStorage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.sendTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.connectionError ||
            e.error is SocketException) {
          // Show a simple toast — don't block the app
          AppToast.showError(
            null,
            title: 'Connection Problem',
            message: 'Please check your internet connection and try again.',
          );
        }
        return handler.next(e);
      },
    ));
  }

  // HTTP GET request with automatic Hive caching and offline fallback
  Future<Response> getAndCache(String path, {Map<String, dynamic>? queryParameters}) async {
    final cacheKey = '$path:${queryParameters != null ? jsonEncode(queryParameters) : ''}';
    try {
      final response = await dio.get(path, queryParameters: queryParameters);
      if (response.statusCode == 200 && response.data != null) {
        await LocalStorage.cacheData(cacheKey, response.data);
      }
      return response;
    } catch (e) {
      debugPrint('ApiClient.getAndCache network error for $path: $e. Checking local Hive cache...');
      final cachedData = LocalStorage.getCachedData(cacheKey);
      if (cachedData != null) {
        debugPrint('ApiClient.getAndCache served offline cache for $path');
        return Response(
          requestOptions: RequestOptions(path: path, queryParameters: queryParameters),
          data: cachedData,
          statusCode: 200,
        );
      }
      rethrow;
    }
  }

  // Helper method for POST requests
  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await dio.post(path, data: data, queryParameters: queryParameters);
  }

  // Helper method for DELETE requests
  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await dio.delete(path, data: data, queryParameters: queryParameters);
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

