import 'package:flutter/material.dart';

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
      backgroundColor: const Color(0xFF10281E),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          return SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ledger seal: brass ring with forest monogram.
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFE0B45C), width: 2),
                        ),
                        child: Center(
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: const BoxDecoration(
                              color: Color(0xFF134E3A),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                                Icons.account_balance_outlined,
                                size: 32,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text('NEXORA',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              letterSpacing: 5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Container(
                          height: 2,
                          width: 56,
                          color: const Color(0xFFE0B45C)),
                      const SizedBox(height: 10),
                      Text('TRADE LEDGER',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .6),
                              fontSize: 11,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 40),
                      SizedBox(
                        width: 150,
                        child: LinearProgressIndicator(
                          value: .28 + (.64 * t),
                          minHeight: 2,
                          backgroundColor:
                              Colors.white.withValues(alpha: .18),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFE0B45C)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Opening the day book…',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .5),
                              fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
