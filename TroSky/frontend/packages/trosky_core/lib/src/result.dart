import 'app_failure.dart';

/// The outcome of a call that can fail: [Ok] with a value or [Err] with an
/// [AppFailure]. Repositories return these instead of throwing.
sealed class Result<T> {
  const Result();

  bool get isOk => this is Ok<T>;

  /// The value, or null for an [Err].
  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  /// The failure, or null for an [Ok].
  AppFailure? get failureOrNull => switch (this) {
    Ok() => null,
    Err(:final failure) => failure,
  };

  /// Maps the value, keeping a failure as it is.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok(:final value) => Ok(transform(value)),
    Err(:final failure) => Err(failure),
  };

  /// Runs [next] on the value; a failure short-circuits.
  Future<Result<R>> then<R>(Future<Result<R>> Function(T value) next) async =>
      switch (this) {
        Ok(:final value) => next(value),
        Err(:final failure) => Err(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'Err($failure)';
}
