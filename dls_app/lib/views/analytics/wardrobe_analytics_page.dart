import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/wardrobe_controller.dart';
import '../../core/analytics/analytics_store.dart';
import '../../core/analytics/wardrobe_analytics_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/item_image.dart';
import '../../core/widgets/responsive_body.dart';
import '../../models/clothing_item.dart';

/// Local Wardrobe Analytics: health, utilisation, colour mix and style history.
///
/// Everything here is computed on-device from the wardrobe and the local
/// `style_analytics.json` log. There is no server call, so the page behaves
/// identically offline and in a browser.
///
/// [QA TEST POINT] Analytics tab
/// - Empty wardrobe: shows the empty state, not a crash.
/// - Garments but no logged outfits: charts render and Style History shows the
///   "no outfits yet" copy.
/// - Resize the browser: content stays inside the 1100px column, no overflow.
class WardrobeAnalyticsPage extends StatefulWidget {
  const WardrobeAnalyticsPage({super.key});

  @override
  State<WardrobeAnalyticsPage> createState() => _WardrobeAnalyticsPageState();
}

class _WardrobeAnalyticsPageState extends State<WardrobeAnalyticsPage> {
  final WardrobeAnalyticsService _service = const WardrobeAnalyticsService();
  final AnalyticsStore _store = AnalyticsStore();

  bool _loading = true;
  int _windowDays = 30;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Loads the local analytics log. Failures degrade to an empty log.
  Future<void> _load() async {
    await _store.load();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>().items;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // All cheap pure functions, recomputed on every build.
    final health = _service.health(wardrobe);
    final colors = _service.colorBreakdown(wardrobe);
    final categories = _service.categoryBreakdown(wardrobe);
    final usage = _service.utilization(wardrobe, windowDays: _windowDays);
    final trend = _service.styleScoreTrend(_store.outfitEntries);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ResponsiveBody(
            maxWidth: 1100,
            padding: EdgeInsets.zero,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: <Widget>[
                Text(
                  'Wardrobe Analytics',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Computed on-device from your wardrobe and style log.',
                  style: TextStyle(color: AppTheme.onSurfaceVariant),
                ),
                const SizedBox(height: 18),
                if (wardrobe.isEmpty)
                  const _EmptyAnalytics()
                else
                  ..._sections(
                    health: health,
                    colors: colors,
                    categories: categories,
                    usage: usage,
                    trend: trend,
                    avgScore:
                        _service.averageStyleScore(_store.outfitEntries),
                    totalOutfits:
                        _service.totalOutfitsGenerated(_store.outfitEntries),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Handles a tap on the 30/60/90-day window selector.
  void _setWindow(int days) => setState(() => _windowDays = days);
  static String _pctOf(double v) => '${(v * 100).toStringAsFixed(0)}%';

  /// Builds the card stack shown for a non-empty wardrobe.
  List<Widget> _sections({
    required WardrobeHealth health,
    required ColorBreakdown colors,
    required CategoryBreakdown categories,
    required UtilizationReport usage,
    required List<StyleTrendPoint> trend,
    required double avgScore,
    required int totalOutfits,
  }) {
    return <Widget>[
      _SummaryRow(
        averageStyleScore: avgScore,
        totalOutfits: totalOutfits,
        utilization: usage.ratePercent,
      ),
      const SizedBox(height: 18),
      _SectionCard(
        title: 'Wardrobe Health',
        trailing: Text(
          '${health.score}/100',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppTheme.primary,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _MetricBar(
              label: 'Category balance',
              value: health.categoryBalanceScore / 100,
              caption: health.topsToBottomsRatio == null
                  ? 'No bottoms yet'
                  : 'Top-to-bottom '
                      '${health.topsToBottomsRatio!.toStringAsFixed(1)}:1 '
                      '(target 3:1)',
            ),
            const SizedBox(height: 12),
            _MetricBar(
              label: 'Versatility',
              value: health.versatilityScore / 100,
              caption: 'Style tags and colour variety',
            ),
            if (health.notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              for (final note in health.notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $note',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: 'Utilisation',
        trailing: _WindowToggle(
          selected: _windowDays,
          onChanged: _setWindow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${usage.ratePercent.toStringAsFixed(0)}% of your wardrobe worn '
              'in the last ${usage.windowDays} days '
              '(${usage.wornInWindow}/${usage.total})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (usage.mostWorn.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                'Most worn',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              for (final item in usage.mostWorn.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${item.subcategory} (${item.wearCount}x worn)',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: 'Colour mix',
        child: Column(
          children: <Widget>[
            _MetricBar(
              label: 'Neutral',
              value: colors.neutral,
              caption: _pctOf(colors.neutral),
            ),
            const SizedBox(height: 10),
            _MetricBar(
              label: 'Warm',
              value: colors.warm,
              caption: _pctOf(colors.warm),
            ),
            const SizedBox(height: 10),
            _MetricBar(
              label: 'Cool',
              value: colors.cool,
              caption: _pctOf(colors.cool),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _SectionCard(
        title: 'Category breakdown',
        child: Column(
          children: <Widget>[
            for (final key in CategoryBreakdown.displayOrder) ...<Widget>[
              _MetricBar(
                label: key,
                value: categories.shareOf(key),
                caption: '${categories.counts[key] ?? 0} item(s)',
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
      if (trend.isNotEmpty) ...<Widget>[
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Style score trend',
          child: _TrendStrip(points: trend),
        ),
      ],
      if (usage.unworn.isNotEmpty) ...<Widget>[
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Unworn shelf',
          trailing: Text(
            '${usage.unworn.length} item(s)',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          child: _UnwornShelf(items: usage.unworn),
        ),
      ],
      const SizedBox(height: 16),
      _SectionCard(
        title: 'Style history',
        trailing: Text(
          '${_store.outfitEntries.length} log(s)',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        child: _StyleHistory(entries: _store.outfitEntries),
      ),
    ];
  }
}


/// Empty state shown when the wardrobe has no garments yet.
class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: <Widget>[
          Icon(Icons.insights, size: 48, color: AppTheme.onSurfaceVariant),
          SizedBox(height: 12),
          Text(
            'Add garments to unlock analytics.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6),
          Text(
            'Health, utilisation and colour insights appear here.',
            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Rounded card wrapper with an optional trailing widget in its header.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Labelled progress bar used by every chart on this page.
class _MetricBar extends StatelessWidget {
  const _MetricBar({
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;

  /// 0.0 - 1.0 share.
  final double value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    // Clamp so a bad ratio can never overflow the bar.
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            if (caption != null)
              Text(
                caption!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 8,
            backgroundColor: AppTheme.surfaceHighest,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
      ],
    );
  }
}

/// 30 / 60 / 90-day window selector for the utilisation metric.
class _WindowToggle extends StatelessWidget {
  const _WindowToggle({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  static const List<int> _options = <int>[30, 60, 90];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: <Widget>[
        for (final days in _options)
          // Generous tap target for physical-phone testing.
          GestureDetector(
            onTap: () => onChanged(days),
            child: Container(
              constraints: const BoxConstraints(minHeight: 32, minWidth: 44),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    selected == days ? AppTheme.primary : AppTheme.surfaceHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${days}d',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected == days
                      ? Colors.black
                      : AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Three headline numbers across the top of the page.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.averageStyleScore,
    required this.totalOutfits,
    required this.utilization,
  });

  final double averageStyleScore;
  final int totalOutfits;
  final double utilization;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _SummaryTile(
            label: 'Avg style',
            value: averageStyleScore.toStringAsFixed(0),
            suffix: '%',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(label: 'Outfits', value: '$totalOutfits'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            label: 'Utilisation',
            value: utilization.toStringAsFixed(0),
            suffix: '%',
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.suffix = '',
  });

  final String label;
  final String value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          // FittedBox stops long values overflowing a narrow phone column.
          FittedBox(
            child: Text(
              '$value$suffix',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Weekly style-score trend rendered as proportional bars (no chart package).
class _TrendStrip extends StatelessWidget {
  const _TrendStrip({required this.points});

  final List<StyleTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    // Scale against the best week so the tallest bar is full height.
    final peak = points
        .map((p) => p.averageScore)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (final point in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      point.averageScore.toStringAsFixed(0),
                      style: const TextStyle(fontSize: 10),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      // A peak of 0 would otherwise divide by zero.
                      height: 70 * (peak == 0 ? 0 : point.averageScore / peak),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${point.weekStart.day}/${point.weekStart.month}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal shelf of never-worn garments, encouraging re-wearing.
class _UnwornShelf extends StatelessWidget {
  const _UnwornShelf({required this.items});

  final List<ClothingItem> items;

  @override
  Widget build(BuildContext context) {
    final shelf = items.take(12).toList(growable: false);
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shelf.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = shelf[index];
          // Local-first resolver: bundled asset, else a plain placeholder.
          final provider = resolveItemImage(item);
          return SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 92,
                    width: 96,
                    child: provider == null
                        ? const ColoredBox(color: AppTheme.surfaceHighest)
                        : Image(image: provider, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.subcategory,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Reverse-chronological list of logged outfits.
class _StyleHistory extends StatelessWidget {
  const _StyleHistory({required this.entries});

  final List<OutfitLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Text(
        'No outfits logged yet. Generate an outfit to start your style history.',
        style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
      );
    }

    final recent = entries.take(10).toList(growable: false);
    return Column(
      children: <Widget>[
        for (final entry in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                // Style Match % tag.
                Container(
                  constraints: const BoxConstraints(minWidth: 46),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${entry.styleMatchPercent}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        entry.occasionLabel.isEmpty
                            ? entry.occasion
                            : entry.occasionLabel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${entry.timestamp.day}/${entry.timestamp.month} '
                        '${entry.timestamp.year}'
                        '${entry.weather.isEmpty ? '' : ' · ${entry.weather}'}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${entry.itemIds.length} pcs',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
