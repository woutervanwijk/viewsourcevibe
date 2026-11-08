import '../../models/inspection/observed.dart';

/// Short text for a value that is not [Present]: why it is not there.
/// Empty for a [Present] value.
String notPresentText<T>(Observed<T> o) => switch (o) {
      Present<T>() => '',
      Pending<T>() => 'still loading',
      Failed<T>(:final error) => error,
      Unavailable<T>(:final reason, :final detail) =>
        unavailableMessage(reason, detail),
    };

/// "unknown (reason)" for a value that is not [Present].
String unknownText<T>(Observed<T> o) => 'unknown (${notPresentText(o)})';

/// [format] of a Present value, else "unknown (reason)".
String presentOrUnknown<T>(Observed<T> o, String Function(T) format) =>
    o is Present<T> ? format(o.value) : unknownText(o);

/// The same non-Present state as [o], typed as an [Observed] of another type
/// (Pending stays Pending, Failed stays Failed, Unavailable keeps its reason).
/// A Present [o] has no such state and becomes a Failed internal error.
Observed<T> notPresentAs<T>(Observed<Object?> o) {
  if (o is Pending) return Pending<T>();
  if (o is Failed) return Failed<T>(o.error);
  if (o is Unavailable) return Unavailable<T>(o.reason, o.detail);
  return Failed<T>('internal error: a present value has no failure state');
}
