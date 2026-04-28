import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:navis_mobile/core/config/env.dart';
import 'package:navis_mobile/core/error/exceptions.dart';
import 'package:navis_mobile/core/network/supabase_client.dart';

class ApiClient {
  ApiClient._() {
    _dio = Dio(
      BaseOptions(
        baseUrl: Env.apiUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _authInterceptor(),
      _tokenRefreshInterceptor(),
      _retryInterceptor(),
      _errorInterceptor(),
      if (kDebugMode) _loggingInterceptor(),
    ]);
  }

  static final ApiClient instance = ApiClient._();

  late final Dio _dio;
  bool _isRefreshing = false;
  final _refreshCompleter = <Completer<void>>[];

  Dio get dio => _dio;

  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        final session = supabaseClient.auth.currentSession;
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        handler.next(options);
      },
    );
  }

  QueuedInterceptorsWrapper _tokenRefreshInterceptor() {
    return QueuedInterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode != 401) {
          return handler.next(error);
        }

        if (error.requestOptions.extra['retried_after_refresh'] == true) {
          return handler.next(error);
        }

        try {
          if (_isRefreshing) {
            final completer = Completer<void>();
            _refreshCompleter.add(completer);
            await completer.future;
          } else {
            _isRefreshing = true;
            await supabaseClient.auth.refreshSession();
            _isRefreshing = false;
            for (final c in _refreshCompleter) {
              c.complete();
            }
            _refreshCompleter.clear();
          }

          final session = supabaseClient.auth.currentSession;
          if (session == null) {
            await _forceLogout();
            return handler.next(error);
          }

          final opts = error.requestOptions;
          opts.headers['Authorization'] = 'Bearer ${session.accessToken}';
          opts.extra['retried_after_refresh'] = true;

          final response = await _dio.fetch(opts);
          return handler.resolve(response);
        } catch (_) {
          _isRefreshing = false;
          for (final c in _refreshCompleter) {
            c.completeError('refresh failed');
          }
          _refreshCompleter.clear();
          await _forceLogout();
          return handler.next(error);
        }
      },
    );
  }

  InterceptorsWrapper _retryInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) async {
        final retryCount =
            (error.requestOptions.extra['retry_count'] as int?) ?? 0;

        if (retryCount >= 2) {
          return handler.next(error);
        }

        final isRetryable = _isServerError(error) || _isNetworkError(error);
        if (!isRetryable) {
          return handler.next(error);
        }

        final delay = Duration(milliseconds: 500 * (1 << retryCount));
        await Future<void>.delayed(delay);

        error.requestOptions.extra['retry_count'] = retryCount + 1;
        try {
          final response = await _dio.fetch(error.requestOptions);
          return handler.resolve(response);
        } on DioException catch (e) {
          return handler.next(e);
        }
      },
    );
  }

  bool _isServerError(DioException error) {
    final status = error.response?.statusCode;
    return status != null && status >= 500;
  }

  bool _isNetworkError(DioException error) {
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError;
  }

  Future<void> _forceLogout() async {
    try {
      await supabaseClient.auth.signOut();
    } catch (_) {}
  }

  InterceptorsWrapper _errorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) {
        final statusCode = error.response?.statusCode;
        final responseData = error.response?.data;
        final String message;
        if (responseData is Map<String, dynamic>) {
          message = responseData['error']?.toString() ??
              error.message ??
              'Unknown error';
        } else {
          message = error.message ?? 'Unknown error';
        }

        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError) {
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: const NetworkException(),
              type: error.type,
            ),
          );
          return;
        }

        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            error: ServerException(message: message, statusCode: statusCode),
            type: error.type,
          ),
        );
      },
    );
  }

  InterceptorsWrapper _loggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('[API] ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint(
            '[API] ${response.statusCode} ${response.requestOptions.uri}');
        handler.next(response);
      },
      onError: (error, handler) {
        debugPrint(
            '[API] ERROR ${error.response?.statusCode} ${error.requestOptions.uri}');
        handler.next(error);
      },
    );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
  }) {
    return _dio.post<T>(path, data: data);
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
  }) {
    return _dio.put<T>(path, data: data);
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
  }) {
    return _dio.patch<T>(path, data: data);
  }

  Future<Response<T>> delete<T>(String path) {
    return _dio.delete<T>(path);
  }
}
