import 'dart:math' as math;

import 'package:flutter/material.dart';

class DashedDivider extends StatelessWidget {
  final double thickness;
  final double dashWidth;
  final double dashGap;
  final Color color;

  const DashedDivider({
    super.key,
    this.thickness = 1.5,
    this.dashWidth = 8,
    this.dashGap = 6,
    this.color = const Color(0xFFBDBDBD),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thickness,
      child: CustomPaint(
        painter: _DashedLinePainter(
          color: color,
          thickness: thickness,
          dashWidth: dashWidth,
          dashGap: dashGap,
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double thickness;
  final double dashWidth;
  final double dashGap;

  _DashedLinePainter({
    required this.color,
    required this.thickness,
    required this.dashWidth,
    required this.dashGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness;

    double x = 0.0;
    final double y = size.height / 2.0;

    while (x < size.width) {
      final double x2 = math.min(x + dashWidth, size.width); // ← stays double
      canvas.drawLine(Offset(x, y), Offset(x2, y), paint);
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) =>
      old.color != color ||
      old.thickness != thickness ||
      old.dashWidth != dashWidth ||
      old.dashGap != dashGap;
}
