import 'package:flutter/material.dart';

/// Keeps phone layouts compact while preventing desktop/web content from
/// stretching into hard-to-scan lines.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

int responsiveColumns(
  double width, {
  int compact = 2,
  int medium = 3,
  int expanded = 4,
}) {
  if (width >= 1000) return expanded;
  if (width >= 620) return medium;
  return compact;
}
