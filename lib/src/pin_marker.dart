import 'package:flutter/material.dart';

class FlatPinMarker extends StatelessWidget {
  final Color color;
  final Color highlightColor;
  final Color stickColor;

  const FlatPinMarker({
    super.key,
    this.color = const Color(0xFFE53935), // red
    this.highlightColor = const Color(0xFFFF8A80),
    this.stickColor = const Color(0xFF424A60),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, co) {
        final markerSize = co.maxHeight * .55;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: co.maxHeight * .55,
              height: co.maxHeight * .55,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              padding: EdgeInsets.all(2),
              child: Align(
                alignment: AlignmentGeometry.topLeft,
                child: Container(
                  width: (co.maxHeight * .55) * .3,
                  height: (co.maxHeight * .55) * .3,
                  decoration: BoxDecoration(
                    color: highlightColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            // Stack(
            //   children: [
            //     Container(
            //       width: size,
            //       height: size,
            //       decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            //     ),
            //     Positioned(
            //       top: size * 0.18,
            //       left: size * 0.18,
            //       child: Container(
            //         width: size * 0.25,
            //         height: size * 0.25,
            // decoration: BoxDecoration(
            //   color: highlightColor,
            //   shape: BoxShape.circle,
            // ),
            //       ),
            //     ),
            //   ],
            // ),

            // Stick
            Expanded(
              child: Center(
                child: Container(
                  width: 3,
                  decoration: BoxDecoration(
                    color: stickColor,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(55),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
