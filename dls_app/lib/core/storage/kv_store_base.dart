/// Platform-neutral key/value persistence used by the on-device stores.
///
/// The app targets Android and **web (Safari on iPhone)**, so anything that used
/// to reach for `dart:io` + `path_provider` unconditionally now goes through this
/// abstraction. On mobile it is a real file; on web it is `localStorage`; and
/// there is an in-memory fallback so nothing can ever hard-fail at startup.
abstract class KvStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Last-resort store: keeps values for the lifetime of the process only.
///
/// Used when neither a writable directory nor `localStorage` is available, and
/// in unit tests. Never throws.
class MemoryKvStore implements KvStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
