import 'package:flutter/material.dart';

/// Constrains page content to a comfortable reading width.
///
/// Flutter Web sizes its canvas to the browser window, so an unconstrained
/// [ListView] stretches cards across a 1920px desktop monitor and makes forms
/// unreadable. This centres the content and caps the width, while leaving
/// narrow (phone) viewports completely untouched.
///
/// Apply it around the *content* of a page, not around full-bleed backgrounds.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 760,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Horizontal inset that grows on wide viewports so text lines never run
/// edge to edge. Pair with [ResponsiveBody] for page-level layouts.
EdgeInsets responsivePagePadding(BuildContext context, {double maxWidth = 760}) {
  final width = MediaQuery.sizeOf(context).width;
  final gutter = width > maxWidth ? 24.0 : 16.0;
  return EdgeInsets.fromLTRB(gutter, 12, gutter, 24);
}
