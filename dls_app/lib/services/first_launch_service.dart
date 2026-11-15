import '../core/storage/kv_store.dart';

/// Tracks small one-time "has this been shown" local flags.
///
/// Local-only by design (reuses the existing [KvStore] abstraction already
/// used for cached weather - a real file on mobile, `localStorage` on web,
/// in-memory in tests - rather than adding a new persistence dependency): a
/// user who reinstalls sees the value-prop carousel again, which is an
/// acceptable tradeoff for a one-time intro, not a bug.
class FirstLaunchService {
  FirstLaunchService({Future<KvStore> Function()? storeProvider})
      : _storeProvider = storeProvider ?? createDefaultKvStore;

  static const String _valuePropCarouselKey = 'has_seen_value_prop_carousel';
  static const String _legalTermsAcceptedKey = 'has_accepted_legal_terms';

  final Future<KvStore> Function() _storeProvider;
  KvStore? _store;

  Future<KvStore> _kvStore() async => _store ??= await _storeProvider();

  Future<bool> hasSeenValuePropCarousel() async {
    final store = await _kvStore();
    return (await store.read(_valuePropCarouselKey)) == 'true';
  }

  Future<void> markValuePropCarouselSeen() async {
    final store = await _kvStore();
    await store.write(_valuePropCarouselKey, 'true');
  }

  /// Whether this device has already accepted the Privacy Policy and Terms
  /// of Service. Local-only, same tradeoff as the carousel flag above: a
  /// reinstall asks again, which is acceptable (and arguably correct, since
  /// the terms may have changed since).
  Future<bool> hasAcceptedLegalTerms() async {
    final store = await _kvStore();
    return (await store.read(_legalTermsAcceptedKey)) == 'true';
  }

  Future<void> markLegalTermsAccepted() async {
    final store = await _kvStore();
    await store.write(_legalTermsAcceptedKey, 'true');
  }
}
