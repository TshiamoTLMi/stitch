import 'package:flutter_test/flutter_test.dart';

import 'package:dls_app/core/storage/kv_store_base.dart';
import 'package:dls_app/services/first_launch_service.dart';

void main() {
  test('has not seen the carousel until it is marked seen', () async {
    final store = MemoryKvStore();
    final service = FirstLaunchService(storeProvider: () async => store);

    expect(await service.hasSeenValuePropCarousel(), isFalse);

    await service.markValuePropCarouselSeen();

    expect(await service.hasSeenValuePropCarousel(), isTrue);
  });

  test('the seen flag persists across new service instances backed by the '
      'same store - simulating an app restart', () async {
    final store = MemoryKvStore();
    await FirstLaunchService(storeProvider: () async => store)
        .markValuePropCarouselSeen();

    final restarted = FirstLaunchService(storeProvider: () async => store);
    expect(await restarted.hasSeenValuePropCarousel(), isTrue);
  });
}
