import 'kv_store_base.dart';

/// In-memory store for platforms with no durable storage (and for tests).
Future<KvStore> createDefaultKvStore() async => MemoryKvStore();
