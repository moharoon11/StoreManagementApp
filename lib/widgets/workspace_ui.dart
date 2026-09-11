import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'ui_breakpoints.dart';

/// Reusable atmospheric backdrop shared by the auth flow and workspace.
class WorkspaceBackdrop extends StatelessWidget {
  const WorkspaceBackdrop({
    super.key,
    this.child,
  });

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = Theme.of(context).scaffoldBackgroundColor;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _blend(background, scheme.primary, .025),
            _blend(background, scheme.secondary, .035),
            _blend(background, scheme.surface, .01),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BackdropGridPainter(
                color: scheme.onSurface.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? .055
                      : .03,
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: _BackdropGlow(
              size: 320,
              color: scheme.primary.withValues(alpha: .18),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -90,
            child: _BackdropGlow(
              size: 360,
              color: scheme.secondary.withValues(alpha: .12),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }

  static Color _blend(Color a, Color b, double amount) =>
      Color.lerp(a, b, amount) ?? a;
}

class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackdropGridPainter extends CustomPainter {
  const _BackdropGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 56.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (var x = 0.0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (var y = 0.0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropGridPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Shared page scaffolding and building blocks for the redesigned workspace.
class WorkspacePage extends StatelessWidget {
  const WorkspacePage({
    super.key,
    required this.child,
    this.padding,
    this.scroll = true,
  });

  final Widget child;
  final EdgeInsets? padding;
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Ui.maxContentWidth),
          child: Padding(
            padding: padding ?? Ui.pagePadding(context),
            child: child,
          ),
        ),
      ),
    );
  }
}

class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    this.action,
  });

  final String eyebrow;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SurfacePanel(
      color: _blend(scheme.surface, scheme.primary, .025),
      padding: EdgeInsets.all(Ui.isCompact(context) ? 18 : 22),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 18,
        runSpacing: 18,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      eyebrow.toUpperCase(),
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: textTheme.headlineLarge?.copyWith(
                    fontSize: Ui.headingSize(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurface.withValues(alpha: .7),
                  ),
                ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final panelColor = color ?? scheme.surface;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: scheme.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            panelColor,
            _blend(panelColor, scheme.primary, .018),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: .08),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class SectionPanel extends StatelessWidget {
  const SectionPanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    this.padding = const EdgeInsets.all(18),
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? action;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SurfacePanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedHeight = constraints.maxHeight.isFinite;
          final body = Padding(padding: padding, child: child);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .06),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: textTheme.titleLarge),
                          if (subtitle != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              subtitle!,
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface.withValues(alpha: .65),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(width: 12),
                      action!,
                    ],
                  ],
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              if (hasBoundedHeight) Expanded(child: body) else body,
            ],
          );
        },
      ),
    );
  }
}

class AdaptiveWrapGrid extends StatelessWidget {
  const AdaptiveWrapGrid({
    super.key,
    required this.children,
    required this.minItemWidth,
    this.spacing = 14,
    this.runSpacing = 14,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = math.max(
          1,
          ((availableWidth + spacing) / (minItemWidth + spacing)).floor(),
        );
        final totalSpacing = spacing * (columns - 1);
        final itemWidth = (availableWidth - totalSpacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.note,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SurfacePanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const Spacer(),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: .72,
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            label.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: .58),
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(value, style: textTheme.headlineSmall),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note!,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: .66),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.background,
  });

  final String label;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class EmptyCanvas extends StatelessWidget {
  const EmptyCanvas({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SurfacePanel(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          color: _blend(scheme.surface, scheme.primary, .015),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: scheme.primary, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withValues(alpha: .66),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _blend(Color a, Color b, double amount) => Color.lerp(a, b, amount) ?? a;
