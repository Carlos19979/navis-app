class ServerException implements Exception {
  const ServerException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ServerException: $message (status: $statusCode)';
}

class NetworkException implements Exception {
  const NetworkException({this.message = 'Network connection failed'});

  final String message;

  @override
  String toString() => 'NetworkException: $message';
}
