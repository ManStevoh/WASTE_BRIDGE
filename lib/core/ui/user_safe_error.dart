import 'package:dio/dio.dart';

/// JSON `message` from a Dio error response when present; otherwise null.
/// Combine with [userVisibleError] when you want server text first:
/// `dioResponseMessage(e) ?? userVisibleError(e, fallback: '…')`.
String? dioResponseMessage(DioException error) {
  final data = error.response?.data;
  if (data is Map && data['message'] != null) {
    final m = data['message'].toString();
    if (m.isNotEmpty) return m;
  }
  return null;
}

/// Short, user-facing copy for failures — see [DOCS/UI_GUIDE.md] §11.
String userVisibleError(
  Object? error, {
  String fallback = 'Something went wrong. Try again.',
}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'].toString();
      if (m.isNotEmpty) {
        return m;
      }
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'The request timed out. Check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'Could not reach the server. Check your internet connection.';
      case DioExceptionType.badResponse:
        return fallback;
      default:
        final msg = error.message;
        if (msg != null && msg.isNotEmpty) {
          return msg;
        }
        return fallback;
    }
  }
  return fallback;
}
