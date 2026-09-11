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
    final compact = Ui.isCompact(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _blend(background, scheme.primary, compact ? .012 : .025),
            _blend(background, scheme.secondary, compact ? .016 : .035),
            _blend(background, scheme.surface, .008),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!compact)
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
          if (!compact)
            Positioned(
              top: -120,
              right: -80,
              child: _BackdropGlow(
                size: 320,
                color: scheme.primary.withValues(alpha: .18),
              ),
            ),
          if (!compact)
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
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width < Ui.phoneMax
        ? 392.0
        : width < 560
            ? 428.0
            : width < Ui.compactMax
                ? 520.0
                : Ui.maxContentWidth;

    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
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
    final compact = Ui.isCompact(context);

    final introCopy = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 660),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 8 : 10,
                height: compact ? 8 : 10,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              Text(
                eyebrow.toUpperCase(),
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  letterSpacing: compact ? 1.8 : 2.2,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          Text(
            title,
            style: (compact ? textTheme.headlineSmall : textTheme.headlineLarge)
                ?.copyWith(
              fontSize: Ui.headingSize(context),
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            description,
            maxLines: compact ? 2 : null,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
            style: (compact ? textTheme.bodyMedium : textTheme.bodyLarge)
                ?.copyWith(
              color: scheme.onSurface.withValues(alpha: .7),
            ),
          ),
        ],
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          introCopy,
          if (action != null) ...[
            const SizedBox(height: 10),
            action!,
          ],
        ],
      );
    }

    return SurfacePanel(
      color: _blend(scheme.surface, scheme.primary, .025),
      padding: const EdgeInsets.all(22),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 18,
        runSpacing: 18,
        children: [
          introCopy,
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
    final phone = Ui.isPhone(context);
    final compact = Ui.isCompact(context);
    final radius = phone
        ? 18.0
        : compact
            ? 22.0
            : 28.0;
    final resolvedPadding = padding == const EdgeInsets.all(18)
        ? EdgeInsets.all(phone
            ? 12
            : compact
                ? 14
                : 18)
        : padding;

    return Container(
      padding: resolvedPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: phone ? .78 : 1),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            panelColor,
            _blend(panelColor, scheme.primary, phone ? .008 : .018),
          ],
        ),
        boxShadow: phone
            ? const []
            : [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: compact ? .05 : .08),
                  blurRadius: compact ? 18 : 30,
                  offset: Offset(0, compact ? 8 : 16),
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
    final phone = Ui.isPhone(context);
    final compact = Ui.isCompact(context);
    final radius = phone
        ? 18.0
        : compact
            ? 22.0
            : 28.0;
    final resolvedPadding = phone
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
        : compact
            ? const EdgeInsets.symmetric(horizontal: 14, vertical: 14)
            : padding;

    return SurfacePanel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hasBoundedHeight = constraints.maxHeight.isFinite;
          final body = Padding(padding: resolvedPadding, child: child);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: resolvedPadding,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: phone ? .04 : .06),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radius),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: compact
                                ? textTheme.titleMedium
                                : textTheme.titleLarge,
                          ),
                          if (subtitle != null) ...[
                            SizedBox(height: compact ? 4 : 6),
                            Text(
                              subtitle!,
                              maxLines: compact ? 2 : null,
                              overflow: compact
                                  ? TextOverflow.ellipsis
                                  : TextOverflow.visible,
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
    this.compactMinItemWidth,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;
  final double? compactMinItemWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final effectiveMinWidth = Ui.isCompact(context)
            ? compactMinItemWidth ?? math.min(minItemWidth, 150)
            : minItemWidth;
        final columns = math.max(
          1,
          ((availableWidth + spacing) / (effectiveMinWidth + spacing)).floor(),
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
    final compact = Ui.isCompact(context);

    return SurfacePanel(
      padding: EdgeInsets.all(compact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 40 : 46,
                height: compact ? 40 : 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(compact ? 14 : 16),
                ),
                child: Icon(icon, size: compact ? 18 : 20, color: color),
              ),
              const Spacer(),
              Container(
                width: compact ? 36 : 44,
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
          SizedBox(height: compact ? 12 : 18),
          Text(
            label.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: scheme.onSurface.withValues(alpha: .58),
              letterSpacing: compact ? 1.2 : 1.6,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            value,
            style: compact ? textTheme.titleLarge : textTheme.headlineSmall,
          ),
          if (note != null) ...[
            SizedBox(height: compact ? 6 : 8),
            Text(
              note!,
              maxLines: compact ? 2 : null,
              overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
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
    final compact = Ui.isCompact(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 6 : 8,
      ),
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
    final compact = Ui.isCompact(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 360 : 420),
        child: SurfacePanel(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 18 : 24,
            vertical: compact ? 20 : 28,
          ),
          color: _blend(scheme.surface, scheme.primary, .015),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 58 : 74,
                height: compact ? 58 : 74,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(icon, color: scheme.primary, size: compact ? 24 : 30),
              ),
              SizedBox(height: compact ? 14 : 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.titleLarge,
              ),
              SizedBox(height: compact ? 6 : 8),
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
