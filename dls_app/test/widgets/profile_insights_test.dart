import 'package:dls_app/models/profile_analytics_state.dart';
import 'package:dls_app/views/home/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProfileAnalyticsState state({
    required AnalyticsStatus status,
    AnalyticsFreshness freshness = AnalyticsFreshness.live,
    int? items = 4,
    int? outfits = 2,
    int? events = 1,
    double? styleScore = 3.5,
    String? message,
  }) {
    return ProfileAnalyticsState(
      status: status,
      freshness: freshness,
      itemCount: items,
      outfitCount: outfits,
      eventCount: events,
      styleScore: styleScore,
      topCategory: 'Shirts',
      latestCaption: 'A clean look',
      timeline: const <StyleEvolutionEntry>[],
      message: message,
    );
  }

  testWidgets('renders readable metrics and cached state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileAnalyticsSummary(
            metrics: state(status: AnalyticsStatus.ready, freshness: AnalyticsFreshness.cached),
          ),
        ),
      ),
    );

    expect(find.text('4'), findsOneWidget);
    expect(find.text('Items in Closet'), findsOneWidget);
    expect(find.text('Outfits Logged'), findsOneWidget);
    expect(find.text('Events Planned'), findsOneWidget);
    expect(find.textContaining('cached insights'), findsOneWidget);
  });

  testWidgets('renders empty guidance without fabricated unavailable values', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileAnalyticsSummary(
            metrics: state(
              status: AnalyticsStatus.empty,
              items: 0,
              outfits: 0,
              events: 0,
              styleScore: null,
              freshness: AnalyticsFreshness.live,
            ),
          ),
        ),
      ),
    );

    expect(find.text('No activity yet. Add wardrobe items or generate an outfit to build this view.'), findsOneWidget);
    expect(find.text('Unavailable'), findsOneWidget);
  });

  testWidgets('renders retryable error state', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileAnalyticsSummary(
            metrics: state(
              status: AnalyticsStatus.error,
              freshness: AnalyticsFreshness.unavailable,
              items: null,
              outfits: null,
              events: null,
              message: 'Profile data could not be refreshed.',
            ),
            onRetry: () => retries++,
          ),
        ),
      ),
    );

    expect(find.text('Profile data could not be refreshed.'), findsOneWidget);
    await tester.tap(find.text('Retry insights'));
    expect(retries, 1);
  });
}