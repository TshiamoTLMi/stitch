import 'package:flutter_test/flutter_test.dart';

import 'package:dls_app/services/wardrobe_repository.dart';
import 'package:dls_app/services/wardrobe_service.dart';

/// Records calls instead of touching Firestore - there is no Firestore test
/// harness in this project, so `markItemsWorn`'s own batch-write body is not
/// exercised here; this guards the delegation contract
/// [WardrobeRepository]/[WardrobeController] depend on.
class _RecordingWardrobeService extends WardrobeService {
  final List<(List<String>, DateTime)> calls = [];

  @override
  Future<void> markItemsWorn(List<String> itemIds, DateTime when) async {
    calls.add((itemIds, when));
  }
}

void main() {
  test('markItemsWorn delegates to the underlying service with the same '
      'ids and timestamp', () async {
    final fake = _RecordingWardrobeService();
    final repository = WardrobeRepository(service: fake);
    final when = DateTime(2026, 6, 1, 9);

    await repository.markItemsWorn(const ['a', 'b', 'c'], when);

    expect(fake.calls, hasLength(1));
    expect(fake.calls.single.$1, const ['a', 'b', 'c']);
    expect(fake.calls.single.$2, when);
  });

  test('an empty id list is still passed through untouched (no crash)',
      () async {
    final fake = _RecordingWardrobeService();
    final repository = WardrobeRepository(service: fake);

    await repository.markItemsWorn(const [], DateTime(2026, 1, 1));

    expect(fake.calls, hasLength(1));
    expect(fake.calls.single.$1, isEmpty);
  });
}
