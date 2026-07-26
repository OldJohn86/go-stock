import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import 'home_page.dart';

/// Brand splash screen with animated gradient background and API connectivity
/// check. Automatically navigates to [HomePage] after 2 seconds.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;
  late final AnimationController _gradientController;
  String? _connectionStatus;
  bool _checkedConnection = false;
  bool _connected = false;

  @override
  void initState() {
    super.initState();

    // Scale-up animation for the logo
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    _scaleController.forward();

    // Subtle gradient shift animation
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _checkConnectivity();
    _scheduleNavigation();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final resp = await ApiClient().get('/settings');
      if (mounted) {
        setState(() {
          _connected = resp.isSuccess;
          _connectionStatus =
              resp.isSuccess ? '服务器连接正常' : '服务器连接异常';
          _checkedConnection = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connected = false;
          _connectionStatus = '无法连接到服务器';
          _checkedConnection = true;
        });
      }
    }
  }

  void _scheduleNavigation() {
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _gradientController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFF0D47A1),
                    const Color(0xFF1565C0),
                    _gradientController.value,
                  )!,
                  Color.lerp(
                    const Color(0xFF1565C0),
                    const Color(0xFF1976D2),
                    _gradientController.value,
                  )!,
                  Color.lerp(
                    const Color(0xFF1976D2),
                    const Color(0xFF42A5F5),
                    _gradientController.value,
                  )!,
                ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                // Animated logo
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.show_chart,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Brand name
                const Text(
                  'go-stock',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                // Subtitle
                Text(
                  'AI 智能选股 · 实时行情',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.8),
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(flex: 2),
                // API connectivity status
                if (_checkedConnection)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _connected ? Colors.greenAccent : Colors.orangeAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _connectionStatus ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
