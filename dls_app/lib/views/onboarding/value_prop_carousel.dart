import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class _ValuePropSlide {
  const _ValuePropSlide({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

const List<_ValuePropSlide> _slides = [
  _ValuePropSlide(
    icon: Icons.camera_alt_outlined,
    title: 'Snap Your Outfit',
    body:
        'Photograph a full outfit and DLS splits it into Top, Bottom and Shoes for your closet - no cloud AI, just fast on-device scanning.',
  ),
  _ValuePropSlide(
    icon: Icons.auto_awesome_outlined,
    title: 'Smart Offline Styling',
    body:
        'Get outfit suggestions that work with real weather and your own wardrobe, generated entirely on your device.',
  ),
  _ValuePropSlide(
    icon: Icons.checkroom_outlined,
    title: 'Track Your Wardrobe',
    body:
        'See what you actually wear, spot cost-per-wear and rediscover pieces you forgot you owned.',
  ),
];

/// Shown once, pre-auth, before the login/signup switcher. Skip is always
/// enabled; once skipped or completed, the caller is responsible for
/// persisting that (see [FirstLaunchService]) so it never reappears.
class ValuePropCarousel extends StatefulWidget {
  const ValuePropCarousel({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<ValuePropCarousel> createState() => _ValuePropCarouselState();
}

class _ValuePropCarouselState extends State<ValuePropCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _slides.length - 1) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton(
                  onPressed: widget.onDone,
                  child: const Text('Skip'),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? AppTheme.primary
                          : AppTheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  child: Text(isLast ? 'Get Started' : 'Next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _ValuePropSlide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLow,
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 56, color: AppTheme.primary),
          ),
          const SizedBox(height: 32),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
