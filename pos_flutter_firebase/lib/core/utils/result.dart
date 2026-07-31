sealed class Result<T> {
  const Result();
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  T get data => (this as Success<T>).value;
  String get errorMessage => (this as Failure<T>).message;
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

class Failure<T> extends Result<T> {
  const Failure(this.message, {this.exception});
  final String message;
  final Object? exception;
}

extension ResultExtensions<T> on Result<T> {
  void onSuccess(void Function(T data) fn) {
    if (this is Success<T>) fn((this as Success<T>).value);
  }

  void onFailure(void Function(String message) fn) {
    if (this is Failure<T>) fn((this as Failure<T>).message);
  }
}
