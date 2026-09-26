enum AnalyticsStatus { loading, ready, empty, partial, error, offline }

enum AnalyticsFreshness { live, cached, stale, unavailable }

class ProfileMetricValue {
  const ProfileMetricValue({required this.label, required this.value});

  final String label;
  final String value;
}

class StyleEvolutionEntry {
  const StyleEvolutionEntry({
    required this.createdAt,
    required this.label,
    required this.description,
  });

  final DateTime? createdAt;
  final String label;
  final String description;
}

class ProfileAnalyticsState {
  const ProfileAnalyticsState({
    required this.status,
    required this.freshness,
    required this.itemCount,
    required this.outfitCount,
    required this.eventCount,
    required this.styleScore,
    required this.topCategory,
    required this.latestCaption,
    required this.timeline,
    this.message,
  });

  const ProfileAnalyticsState.loading()
      : status = AnalyticsStatus.loading,
        freshness = AnalyticsFreshness.unavailable,
        itemCount = null,
        outfitCount = null,
        eventCount = null,
        styleScore = null,
        topCategory = null,
        latestCaption = null,
        timeline = const <StyleEvolutionEntry>[],
        message = null;

  final AnalyticsStatus status;
  final AnalyticsFreshness freshness;
  final int? itemCount;
  final int? outfitCount;
  final int? eventCount;
  final double? styleScore;
  final String? topCategory;
  final String? latestCaption;
  final List<StyleEvolutionEntry> timeline;
  final String? message;

  bool get canRetry => status == AnalyticsStatus.error || status == AnalyticsStatus.offline;

  bool get hasUsableMetrics => itemCount != null || outfitCount != null || eventCount != null;

  ProfileAnalyticsState copyWith({
    AnalyticsStatus? status,
    AnalyticsFreshness? freshness,
    int? itemCount,
    int? outfitCount,
    int? eventCount,
    double? styleScore,
    String? topCategory,
    String? latestCaption,
    List<StyleEvolutionEntry>? timeline,
    String? message,
  }) {
    return ProfileAnalyticsState(
      status: status ?? this.status,
      freshness: freshness ?? this.freshness,
      itemCount: itemCount ?? this.itemCount,
      outfitCount: outfitCount ?? this.outfitCount,
      eventCount: eventCount ?? this.eventCount,
      styleScore: styleScore ?? this.styleScore,
      topCategory: topCategory ?? this.topCategory,
      latestCaption: latestCaption ?? this.latestCaption,
      timeline: timeline ?? this.timeline,
      message: message ?? this.message,
    );
  }
}