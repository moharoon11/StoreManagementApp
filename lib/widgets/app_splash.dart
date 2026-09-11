import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'workspace_ui.dart';

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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: WorkspaceBackdrop(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_controller.value);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 10),
                  child: Opacity(
                    opacity: .84 + (.16 * t),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: SurfacePanel(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 28,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.rotate(
                              angle:
                                  math.sin(_controller.value * math.pi) * .03,
                              child: Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  color: scheme.primary,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(
                                  Icons.auto_graph_rounded,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'NEXORA',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(letterSpacing: 3.4),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Commerce, in perfect flow.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color:
                                        scheme.onSurface.withValues(alpha: .68),
                                  ),
                            ),
                            const SizedBox(height: 26),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: .28 + (.6 * t),
                                minHeight: 5,
                                backgroundColor:
                                    scheme.primary.withValues(alpha: .12),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    scheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
