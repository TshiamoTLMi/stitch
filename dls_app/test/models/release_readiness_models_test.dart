import 'package:dls_app/models/missing_item_recommendation.dart';
import 'package:dls_app/models/profile_analytics_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recommendation exposes explainable action and dedupe identity', () {
    const recommendation = MissingItemRecommendation(
      need: 'Formal shoes',
      reason: 'Work event: formal shoes complete the occasion.',
      eventId: 'event-redacted',
      eventName: 'Test event',
      occasion: 'Work',
      state: RecommendationState.missing,
      action: RecommendationAction.addToWardrobe,
      dedupeKey: 'formal shoes|addToWardrobe',
    );

    expect(recommendation.actionLabel, 'Add to wardrobe');
    expect(recommendation.dedupeKey, contains('formal shoes'));
  });

  test('analytics loading does not fabricate zero values', () {
    const state = ProfileAnalyticsState.loading();

    expect(state.status, AnalyticsStatus.loading);
    expect(state.itemCount, isNull);
    expect(state.styleScore, isNull);
    expect(state.canRetry, isFalse);
  });
}