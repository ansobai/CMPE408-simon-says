class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode, $message)';
}

class ApiNetworkException extends ApiException {
  const ApiNetworkException(super.message);
}

class ApiRequestException extends ApiException {
  const ApiRequestException(super.message, {super.statusCode});
}

class ApiUnauthorizedException extends ApiException {
  const ApiUnauthorizedException([
    super.message = 'Your session has expired. Please sign in again.',
  ]) : super(statusCode: 401);
}

class ApiGoneException extends ApiException {
  const ApiGoneException([
    super.message = 'This account is no longer available.',
  ]) : super(statusCode: 410);
}
