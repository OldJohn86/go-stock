import 'package:flutter/material.dart';

/// 骨架屏加载占位组件
class Skeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const Skeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 8,
  });

  const Skeleton.circle({super.key, required double size, this.borderRadius = 0})
      : width = size,
        height = size;

  const Skeleton.line({super.key, this.width = double.infinity, this.height = 14, this.borderRadius = 4});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: _animation.value),
          ),
        );
      },
    );
  }
}

/// 骨架屏列表卡片
class SkeletonCard extends StatelessWidget {
  final double height;
  const SkeletonCard({super.key, this.height = 100});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Skeleton.circle(size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Skeleton(width: 120, height: 14),
                      const Spacer(),
                      Skeleton(width: 60, height: 12, borderRadius: 12),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Skeleton(width: 160, height: 14),
                  const SizedBox(height: 6),
                  const Skeleton(width: 200, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 交易记录页骨架屏
class TradingRecordSkeleton extends StatelessWidget {
  const TradingRecordSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Skeleton(width: 80, height: 14),
                    SizedBox(width: 8),
                    Skeleton(width: 100, height: 24),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(4, (_) => const Column(
                    children: [
                      Skeleton(width: 20, height: 20, borderRadius: 10),
                      SizedBox(height: 4),
                      Skeleton(width: 50, height: 16),
                      SizedBox(height: 2),
                      Skeleton(width: 40, height: 12),
                    ],
                  )),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(5, (_) => const Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: SkeletonCard(),
        )),
      ],
    );
  }
}

/// 操作计划页骨架屏
class PlanListSkeleton extends StatelessWidget {
  const PlanListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: List.generate(5, (_) => const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: SkeletonCard(height: 130),
      )),
    );
  }
}

/// 板块行情页骨架屏
class SectorRankingSkeleton extends StatelessWidget {
  const SectorRankingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: List.generate(10, (i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Skeleton(width: 24, height: 14),
            const SizedBox(width: 12),
            const Expanded(child: Skeleton(height: 14)),
            const SizedBox(width: 12),
            Skeleton(width: 60, height: 14),
            const SizedBox(width: 12),
            Skeleton(width: 60, height: 14),
          ],
        ),
      )),
    );
  }
}
