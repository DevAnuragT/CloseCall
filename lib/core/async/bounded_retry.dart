import 'dart:async';

/// Retries a read a small, bounded number of times without turning a failed
/// screen into an unbounded background loop.
Future<T> retryWithBackoff<T>({
  required Future<T> Function() operation,
  bool Function()? isCurrent,
  bool Function(Object)? shouldRetry,
  int maxAttempts = 3,
  Duration initialDelay = const Duration(milliseconds: 100),
  Duration maxDelay = const Duration(seconds: 1),
}) async {
  Object? failure;
  StackTrace? stack;
  var delay = initialDelay;

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (failure != null && isCurrent?.call() == false) {
      Error.throwWithStackTrace(failure, stack!);
    }
    try {
      return await operation();
    } catch (error, trace) {
      failure = error;
      stack = trace;
      if (attempt + 1 >= maxAttempts ||
          isCurrent?.call() == false ||
          shouldRetry?.call(error) == false) {
        Error.throwWithStackTrace(failure, stack);
      }
      if (delay == Duration.zero) {
        await Future<void>.value();
      } else {
        await Future<void>.delayed(delay);
      }
      if (delay != Duration.zero) {
        final nextMilliseconds = (delay.inMilliseconds * 2).clamp(
          1,
          maxDelay.inMilliseconds,
        );
        delay = Duration(milliseconds: nextMilliseconds);
      }
    }
  }

  // maxAttempts is public API, so keep an explicit fallback for an invalid
  // zero/negative value rather than allowing a null error to escape.
  Error.throwWithStackTrace(
    failure ?? StateError('Retry attempts must be greater than zero.'),
    stack ?? StackTrace.current,
  );
}
