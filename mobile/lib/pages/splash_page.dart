import 'package:flutter/material.dart';

import 'home_page.dart';

/// 原生启动画面托管层 — Android/iOS 原生 SplashScreen 展示启动画面，
/// 此页面仅在 Flutter 引擎初始化完成后短暂显示，立即跳转到主页。
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 保持和原生启动画面一致的深蓝色背景，避免闪白
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: FutureBuilder(
        future: Future.delayed(const Duration(milliseconds: 100)),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomePage()),
              );
            });
          }
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}
