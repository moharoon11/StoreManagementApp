import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppSplash extends StatefulWidget {
  const AppSplash({super.key});

  @override
  State<AppSplash> createState() => _AppSplashState();
}

class _AppSplashState extends State<AppSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF5EEDF),
                      Color(0xFFE7D7C0),
                      Color(0xFFC4A786),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -120 + (16 * t),
                right: -90,
                child: _SplashOrb(
                  size: 280,
                  color: AppColors.bronze.withValues(alpha: .10),
                ),
              ),
              Positioned(
                bottom: -150,
                left: -70 + (18 * t),
                child: _SplashOrb(
                  size: 320,
                  color: AppColors.sage.withValues(alpha: .10),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 10),
                  child: Opacity(
                    opacity: .82 + (.18 * t),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.rotate(
                          angle: math.sin(_controller.value * math.pi) * .03,
                          child: Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: .12),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_graph_rounded,
                              size: 44,
                              color: AppColors.bronze,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'NEXORA',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                letterSpacing: 4,
                                color: AppColors.ink,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Commerce, with a calmer operating rhythm.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.muted,
                              ),
                        ),
                        const SizedBox(height: 34),
                        SizedBox(
                          width: 132,
                          child: LinearProgressIndicator(
                            value: .28 + (.6 * t),
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(99),
                            backgroundColor:
                                AppColors.bronze.withValues(alpha: .12),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.bronze,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SplashOrb extends StatelessWidget {
  const _SplashOrb({
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
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
