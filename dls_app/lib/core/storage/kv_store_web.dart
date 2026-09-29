import 'package:web/web.dart' as web;

import 'kv_store_base.dart';

/// `localStorage`-backed store for the web build (Safari on iPhone).
///
/// `localStorage` is synchronous but the [KvStore] contract is async, so callers
/// stay platform-neutral. Safari caps this at ~5MB per origin, which is ample
/// for a weight vector and a weather reading.
///
/// Every operation is wrapped: Safari throws in private-browsing mode and when
/// storage is full, and neither should ever crash the app.
class WebKvStore implements KvStore {
  web.Storage? get _storage {
    try {
      return web.window.localStorage;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> read(String key) async {
    try {
      return _storage?.getItem(key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      _storage?.setItem(key, value);
    } catch (_) {
      // Private browsing / quota exceeded: degrade to in-memory for this run.
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      _storage?.removeItem(key);
    } catch (_) {
      // Nothing to do.
    }
  }
}

Future<KvStore> createDefaultKvStore() async => WebKvStore();
