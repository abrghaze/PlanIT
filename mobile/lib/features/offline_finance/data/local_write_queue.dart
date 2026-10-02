/// Read-modify-write operations on a saved collection must run in order.
/// A failed write must not prevent subsequent writes from being attempted.
final class LocalWriteQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
