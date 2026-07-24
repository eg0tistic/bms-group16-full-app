import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkeletonShimmer extends StatelessWidget {
  final Widget child;

  const SkeletonShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: child,
    );
  }
}

class SkeletonListCard extends StatelessWidget {
  const SkeletonListCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const SkeletonBox(width: 38, height: 38, radius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(
                    width: MediaQuery.of(context).size.width * 0.3,
                    height: 12,
                  ),
                  const SizedBox(height: 8),
                  SkeletonBox(
                    width: MediaQuery.of(context).size.width * 0.45,
                    height: 10,
                  ),
                  const SizedBox(height: 6),
                  const SkeletonBox(width: 80, height: 9),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SkeletonBox(width: 70, height: 12),
                SizedBox(height: 8),
                SkeletonBox(width: 16, height: 16, radius: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonKpiCard extends StatelessWidget {
  const SkeletonKpiCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonBox(width: 34, height: 34, radius: 10),
                Spacer(),
                SkeletonBox(width: 8, height: 8, radius: 4),
              ],
            ),
            SizedBox(height: 14),
            SkeletonBox(height: 22, width: 90),
            SizedBox(height: 8),
            SkeletonBox(height: 10, width: 110),
          ],
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int count;

  const SkeletonList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, _) => const SkeletonListCard(),
    );
  }
}
