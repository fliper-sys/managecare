/// Custom exceptions for the application
abstract class AppException implements Exception {
  final String message;

  AppException(this.message);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException(super.message);
}

class ServerException extends AppException {
  final int? statusCode;

  ServerException(super.message, {this.statusCode});
}

class CacheException extends AppException {
  CacheException(super.message);
}

class AuthException extends AppException {
  AuthException(super.message);
}

class ValidationException extends AppException {
  ValidationException(super.message);
}

class NotImplementedException extends AppException {
  NotImplementedException(super.message);
}

class NotFoundException extends AppException {
  NotFoundException(super.message);
}

class DatabaseException extends AppException {
  DatabaseException(super.message);
}

