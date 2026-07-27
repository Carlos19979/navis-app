import 'package:dio/dio.dart';

import 'package:navis_mobile/core/error/exceptions.dart';

/// HTTP 403 — the API's "the owner has not granted you this" answer.
const _forbidden = 403;

/// Whether [error] is the API refusing a write because the boat owner has not
/// granted the caller that permission.
///
/// The interceptor in `ApiClient` wraps every failure as a [DioException]
/// carrying a [ServerException], so screens see a `DioException [bad response]:
/// FORBIDDEN` string unless they ask this. Used as the *safety net* when a
/// mutation is refused anyway; the primary defence is checking
/// `boatPermissionsProvider` before the user does the work.
bool isPermissionDeniedError(Object error) {
  final inner = error is DioException ? error.error : error;
  if (inner is ServerException) return inner.statusCode == _forbidden;
  if (error is DioException) {
    return error.response?.statusCode == _forbidden;
  }
  return false;
}
