import 'package:flutter/foundation.dart';

/// A Result type for handling success and failure cases without exceptions.
/// This provides a more functional approach to error handling.
sealed class Result<T, E> {
  const Result();

  /// Returns true if this is a Success result
  bool get isSuccess => this is Success<T, E>;

  /// Returns true if this is a Failure result
  bool get isFailure => this is Failure<T, E>;

  /// Gets the success value or null if this is a failure
  T? get valueOrNull {
    return switch (this) {
      Success(value: final v) => v,
      Failure() => null,
    };
  }

  /// Gets the error or null if this is a success
  E? get errorOrNull {
    return switch (this) {
      Success() => null,
      Failure(error: final e) => e,
    };
  }

  /// Maps the success value to a new type
  Result<U, E> map<U>(U Function(T value) transform) {
    return switch (this) {
      Success(value: final v) => Success(transform(v)),
      Failure(error: final e) => Failure(e),
    };
  }

  /// Maps the error to a new type
  Result<T, F> mapError<F>(F Function(E error) transform) {
    return switch (this) {
      Success(value: final v) => Success(v),
      Failure(error: final e) => Failure(transform(e)),
    };
  }

  /// Chains another Result-returning operation
  Result<U, E> flatMap<U>(Result<U, E> Function(T value) transform) {
    return switch (this) {
      Success(value: final v) => transform(v),
      Failure(error: final e) => Failure(e),
    };
  }

  /// Folds the result into a single value
  U fold<U>({
    required U Function(T value) onSuccess,
    required U Function(E error) onFailure,
  }) {
    return switch (this) {
      Success(value: final v) => onSuccess(v),
      Failure(error: final e) => onFailure(e),
    };
  }

  /// Gets the value or throws the error
  T getOrThrow() {
    return switch (this) {
      Success(value: final v) => v,
      Failure(error: final e) => throw Exception(e),
    };
  }

  /// Gets the value or returns a default
  T getOrElse(T defaultValue) {
    return switch (this) {
      Success(value: final v) => v,
      Failure() => defaultValue,
    };
  }
}

/// Represents a successful result
@immutable
final class Success<T, E> extends Result<T, E> {

  const Success(this.value);
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// Represents a failed result
@immutable
final class Failure<T, E> extends Result<T, E> {

  const Failure(this.error);
  final E error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T, E> &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}

/// Extension for easy Result creation
extension ResultExtensions<T> on T {
  Result<T, E> asSuccess<E>() => Success(this);
}

/// Extension for creating failures
extension ErrorResultExtensions<E> on E {
  Result<T, E> asFailure<T>() => Failure(this);
}
