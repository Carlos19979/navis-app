abstract class Failure {
  const Failure();
  String get message;
}

class ServerFailure extends Failure {
  const ServerFailure({required this.serverMessage, this.statusCode});

  final String serverMessage;
  final int? statusCode;

  @override
  String get message => serverMessage;
}

class NetworkFailure extends Failure {
  const NetworkFailure({this.networkMessage = 'Network connection failed'});

  final String networkMessage;

  @override
  String get message => networkMessage;
}

class AuthFailure extends Failure {
  const AuthFailure({required this.authMessage});

  final String authMessage;

  @override
  String get message => authMessage;
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({this.notFoundMessage = 'Resource not found'});

  final String notFoundMessage;

  @override
  String get message => notFoundMessage;
}

class ValidationFailure extends Failure {
  const ValidationFailure({
    required this.fieldErrors,
    this.validationMessage = 'Validation failed',
  });

  final Map<String, String> fieldErrors;
  final String validationMessage;

  @override
  String get message => validationMessage;
}
