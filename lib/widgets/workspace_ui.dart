import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WorkspacePage extends StatelessWidget {
  const WorkspacePage(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(28)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: compact ? const EdgeInsets.all(16) : padding,
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
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        runSpacing: 16,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(eyebrow.toUpperCase(),
                style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 10,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(title,
                style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 27,
                    letterSpacing: -1.1,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(description,
                style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ]),
          if (action != null) action!,
        ],
      );
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20),
      this.color});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
            color: color ?? Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
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
  Widget build(BuildContext context) => SurfacePanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: color))
          ]),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 24,
                  letterSpacing: -.8,
                  fontWeight: FontWeight.w800)),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!,
                style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600))
          ],
        ]),
      );
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
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
                color: AppColors.brandSoft, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.brand, size: 30)),
        const SizedBox(height: 16),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.ink)),
        const SizedBox(height: 5),
        Text(detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 12))
      ]));
}
