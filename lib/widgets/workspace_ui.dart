import 'package:flutter/material.dart';
import 'ui_breakpoints.dart';

/// Shared page scaffolding for every workspace view.
/// Ledger style: flat paper background, hairline rules, ruled cards.
class WorkspacePage extends StatelessWidget {
  const WorkspacePage(
      {super.key, required this.child, this.padding, this.scroll = true});
  final Widget child;
  final EdgeInsets? padding;

  /// Kept for API compatibility; pages manage their own scrolling.
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

/// Ruled section header: brass tick, small-caps kicker, strong title,
/// thin rule underneath — like a ledger page heading.
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 26,
              height: 3,
              margin: const EdgeInsets.only(bottom: 5, right: 8),
              decoration: BoxDecoration(
                color: scheme.secondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Text(
                eyebrow.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: scheme.onSurface.withValues(alpha: .55),
                    fontSize: 11,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          runSpacing: 10,
          children: [
            Text(title,
                style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: Ui.headingSize(context),
                    letterSpacing: 0,
                    fontWeight: FontWeight.w700)),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 5),
        Text(description,
            style: TextStyle(
                color: scheme.onSurface.withValues(alpha: .6),
                fontSize: 13,
                fontWeight: FontWeight.w400)),
        const SizedBox(height: 10),
        Divider(color: scheme.outlineVariant, height: 1),
      ],
    );
  }
}

/// Ruled card: white surface, tight corners, hairline border, brass top rule.
class SurfacePanel extends StatelessWidget {
  const SurfacePanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(14),
      this.color,
      this.accent = true});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;

  /// Shows the brass top rule. Turn off for nested panels.
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (accent)
            Container(
              height: 3,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: scheme.secondary.withValues(alpha: .85),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Ledger stat: stamp + label row, big tabular figure, hairline footer note.
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
      accent: false,
      padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, size: 15, color: color)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: scheme.onSurface.withValues(alpha: .6),
                      fontSize: 11,
                      letterSpacing: .8,
                      fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 10),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: scheme.onSurface,
                fontSize: 22,
                letterSpacing: 0,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()])),
        if (note != null) ...[
          const SizedBox(height: 6),
          Container(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 6),
          Text(note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .55),
                  fontSize: 11,
                  fontWeight: FontWeight.w500))
        ],
      ]),
    );
  }
}

/// Empty state: outlined stamp + ruled text, no circles, no pills.
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
        child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: scheme.surface,
                border: Border.all(color: scheme.outlineVariant),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: scheme.primary, size: 26)),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w700, color: scheme.onSurface)),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text(detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .6), fontSize: 12)),
        ),
      ]),
    ));
  }
}

/// Small uppercase kicker used inside cards and sheets.
class LedgerKicker extends StatelessWidget {
  const LedgerKicker(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: scheme.onSurface.withValues(alpha: .5),
            fontSize: 10.5,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700));
  }
}

/// Status chip: square, hairline border, tinted fill — replaces pill badges.
class LedgerTag extends StatelessWidget {
  const LedgerTag(
      {super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        border: Border.all(color: color.withValues(alpha: .4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

/// Tinted square stamp for leading icons in lists.
class LedgerStamp extends StatelessWidget {
  const LedgerStamp({super.key, required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Icon(icon, size: 18, color: color),
      );
}