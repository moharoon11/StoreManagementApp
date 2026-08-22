import 'package:flutter/material.dart';
import 'ui_breakpoints.dart';

/// Shared page scaffolding for every workspace view.
class WorkspacePage extends StatelessWidget {
  const WorkspacePage(
      {super.key, required this.child, this.padding, this.scroll = true});
  final Widget child;
  final EdgeInsets? padding;

  /// When true the page content scrolls and adapts its padding to the
  /// available width.
  final bool scroll;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding ?? Ui.pagePadding(context),
          child: child,
        ),
      ),
    );
  }
}

class PageIntro extends StatelessWidget {
  const PageIntro(
      {super.key,
      required this.eyebrow,
      required this.title,
      required this.description,
      this.action});
  final String eyebrow, title, description;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 12,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(eyebrow.toUpperCase(),
              style: TextStyle(
                  color: scheme.primary,
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(title,
              style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: Ui.headingSize(context),
                  letterSpacing: -1,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(description,
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .62),
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ]),
        if (action != null) action!,
      ],
    );
  }
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(14),
      this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
            color: color ?? Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant)),
        child: child,
      );
}

class StatTile extends StatelessWidget {
  const StatTile(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      required this.color,
      this.note});
  final String label, value;
  final IconData icon;
  final Color color;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SurfacePanel(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: .6),
                      fontSize: 11,
                      fontWeight: FontWeight.w700))),
          Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 16, color: color))
        ]),
        const Spacer(),
        Text(value,
            style: TextStyle(
                color: scheme.onSurface,
                fontSize: 18,
                letterSpacing: -.7,
                fontWeight: FontWeight.w800)),
        if (note != null) ...[
          const SizedBox(height: 3),
          Text(note!,
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .55),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600))
        ],
      ]),
    );
  }
}

class EmptyCanvas extends StatelessWidget {
  const EmptyCanvas(
      {super.key,
      required this.icon,
      required this.title,
      required this.detail});
  final IconData icon;
  final String title, detail;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .1),
              shape: BoxShape.circle),
          child: Icon(icon, color: scheme.primary, size: 27)),
      const SizedBox(height: 13),
      Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w800, color: scheme.onSurface)),
      const SizedBox(height: 4),
      Text(detail,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: scheme.onSurface.withValues(alpha: .6), fontSize: 12))
    ]));
  }
}