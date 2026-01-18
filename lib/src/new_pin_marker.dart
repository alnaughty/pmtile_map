import 'package:flutter/material.dart';

class CustomMapMarker extends StatelessWidget {
  final Widget centerWidget;
  final Color color;
  final Gradient? gradient;

  const CustomMapMarker({
    super.key,
    required this.centerWidget,
    this.color = Colors.red,
    this.gradient,
  });
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.maxWidth;
        final double headRadius = size * 0.42;
        final Offset headCenter = Offset(size / 2, headRadius);
        final double coneJoinY = headCenter.dy + headRadius * 0.65;
        final double coneHeight = size - coneJoinY;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              CustomPaint(
                size: Size(size, size * 1.25),
                painter: _MapMarkerPainter(color: color, gradient: gradient),
              ),
              Positioned(
                bottom: coneHeight,
                child: ClipOval(
                  child: SizedBox(
                    width: headRadius * 1.25,
                    height: headRadius * 1.25,
                    child: centerWidget,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MapMarkerPainter extends CustomPainter {
  final Color color;
  final Gradient? gradient;

  _MapMarkerPainter({this.color = Colors.red, this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final double headRadius = w * 0.42;
    final Offset headCenter = Offset(w / 2, headRadius);

    final double coneTopWidth = w * 0.30;
    final double coneJoinY = headCenter.dy + headRadius * 0.65;

    final Path circlePath = Path()
      ..addOval(Rect.fromCircle(center: headCenter, radius: headRadius));

    final Path conePath = Path()
      ..moveTo(headCenter.dx - coneTopWidth / 2, coneJoinY)
      ..lineTo(w / 2, h)
      ..lineTo(headCenter.dx + coneTopWidth / 2, coneJoinY)
      ..close();

    final Path markerPath = Path.combine(
      PathOperation.union,
      circlePath,
      conePath,
    );

    final double holeRadius = headRadius * 0.7;
    final Path holePath = Path()
      ..addOval(Rect.fromCircle(center: headCenter, radius: holeRadius));

    final Path finalPath = Path.combine(
      PathOperation.difference,
      markerPath,
      holePath,
    );

    final Paint paint = Paint()..style = PaintingStyle.fill;
    if (gradient != null) {
      paint.shader = gradient!.createShader(Rect.fromLTWH(0, 0, w, h));
    } else {
      paint.color = color;
    }

    canvas.drawShadow(finalPath, Colors.black, 4, true);
    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
