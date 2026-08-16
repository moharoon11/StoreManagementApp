import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class WorkdayWelcome extends StatelessWidget {
  const WorkdayWelcome({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppProvider>().username;
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        const DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
              Color(0xFFF8F9FF),
              Color(0xFFEEF0FF),
              Color(0xFFF6F7FB)
            ]))),
        Positioned(
            top: -110,
            right: -70,
            child: _shape(270, const Color(0xFF365FF4).withOpacity(.10))),
        Positioned(
            bottom: -150,
            left: -100,
            child: _shape(350, const Color(0xFF12A594).withOpacity(.11))),
        SafeArea(
            child: SingleChildScrollView(
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Padding(
                            padding: EdgeInsets.all(compact ? 24 : 48),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                            color: AppColors.brand,
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                        child: const Icon(
                                            Icons.auto_graph_rounded,
                                            color: Colors.white)),
                                    const SizedBox(width: 11),
                                    const Text('NEXORA',
                                        style: TextStyle(
                                            letterSpacing: 2,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.ink)),
                                    const Spacer(),
                                    TextButton.icon(
                                        onPressed: onContinue,
                                        icon: const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 17),
                                        label: const Text('Skip to workspace'))
                                  ]),
                                  SizedBox(height: compact ? 40 : 100),
                                  Text(
                                      'Welcome${user.isEmpty ? '' : ', $user'}.',
                                      style: TextStyle(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.w800,
                                          fontSize: compact ? 33 : 48,
                                          letterSpacing: -2)),
                                  const SizedBox(height: 12),
                                  const Text('What would make today a win?',
                                      style: TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 30),
                                  Wrap(spacing: 16, runSpacing: 16, children: [
                                    _JourneyCard(
                                        width: compact ? double.infinity : 290,
                                        index: '01',
                                        icon: Icons.point_of_sale_rounded,
                                        color: const Color(0xFF12A594),
                                        title: 'Start a sale',
                                        text:
                                            'Build a bill and complete checkout in seconds.',
                                        onTap: () {
                                          context
                                              .read<AppProvider>()
                                              .setNavIndex(1);
                                          onContinue();
                                        }),
                                    _JourneyCard(
                                        width: compact ? double.infinity : 290,
                                        index: '02',
                                        icon: Icons.inventory_2_rounded,
                                        color: const Color(0xFF365FF4),
                                        title: 'Manage products',
                                        text:
                                            'Add items, pricing, stock, and favourites.',
                                        onTap: () {
                                          context
                                              .read<AppProvider>()
                                              .setNavIndex(2);
                                          onContinue();
                                        }),
                                    _JourneyCard(
                                        width: compact ? double.infinity : 290,
                                        index: '03',
                                        icon: Icons.auto_graph_rounded,
                                        color: const Color(0xFF8D63D8),
                                        title: 'Review the day',
                                        text:
                                            'See revenue, stock alerts, and what is moving.',
                                        onTap: () {
                                          context
                                              .read<AppProvider>()
                                              .setNavIndex(0);
                                          onContinue();
                                        }),
                                  ]),
                                  const SizedBox(height: 28),
                                  const Text(
                                      'Choose a task to enter your workspace. You can move between every area at any time.',
                                      style: TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 12)),
                                ])))))),
      ]),
    );
  }

  Widget _shape(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard(
      {required this.width,
      required this.index,
      required this.icon,
      required this.color,
      required this.title,
      required this.text,
      required this.onTap});
  final double width;
  final String index, title, text;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            height: 222,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                border: Border.all(color: AppColors.line),
                borderRadius: BorderRadius.circular(22)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: color.withOpacity(.12),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon, color: color)),
                      Text(index,
                          style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800))
                    ]),
                const Spacer(),
                Text(title,
                    style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                Text(text,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12, height: 1.4)),
                const SizedBox(height: 14),
                Row(children: [
                  Text('Open task',
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 5),
                  Icon(Icons.arrow_forward_rounded, color: color, size: 16)
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
