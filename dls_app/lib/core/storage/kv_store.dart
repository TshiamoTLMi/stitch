/// Conditional barrel for the platform key/value store.
///
/// * mobile / desktop -> `kv_store_io.dart` (atomic file writes)
/// * web (Safari)     -> `kv_store_web.dart` (`localStorage`)
/// * anything else    -> `kv_store_memory.dart` (in-memory, never throws)
library;

export 'kv_store_base.dart';
export 'kv_store_memory.dart'
    if (dart.library.io) 'kv_store_io.dart'
    if (dart.library.js_interop) 'kv_store_web.dart';
