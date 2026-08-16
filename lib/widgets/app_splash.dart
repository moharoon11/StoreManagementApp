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
      duration: const Duration(milliseconds: 1800),
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
                      Color(0xFF101A35),
                      Color(0xFF263B89),
                      Color(0xFF365FF4)
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -120 + (18 * t),
                right: -70,
                child: _orb(260, const Color(0xFF82E9DE).withOpacity(.18)),
              ),
              Positioned(
                bottom: -160,
                left: -70 + (20 * t),
                child: _orb(310, Colors.white.withOpacity(.09)),
              ),
              Center(
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 10),
                  child: Opacity(
                    opacity: .78 + (.22 * t),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.rotate(
                          angle: math.sin(_controller.value * math.pi) * .04,
                          child: Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(27),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(.18),
                                    blurRadius: 30,
                                    offset: const Offset(0, 14))
                              ],
                            ),
                            child: const Icon(Icons.auto_graph_rounded,
                                size: 43, color: AppColors.brand),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('NEXORA',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text('Commerce, in perfect flow.',
                            style: TextStyle(
                                color: Colors.white.withOpacity(.72),
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 42),
                        SizedBox(
                          width: 122,
                          child: LinearProgressIndicator(
                            value: .28 + (.64 * t),
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(99),
                            backgroundColor: Colors.white.withOpacity(.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF82E9DE)),
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

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
