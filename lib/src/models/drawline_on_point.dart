import 'package:flutter/material.dart' show Color, Colors, Widget;
import 'package:pmtiles_map/src/models/lat_long.dart';

class DrawLineOnPoint {
  final LatLong start;
  final LatLong end;
  final Color color;
  final double strokeWidth;
  final Widget? startMarker, endMarker;
  final String startLabel, endLabel;

  DrawLineOnPoint({
    this.startMarker,
    this.endMarker,
    required this.start,
    required this.end,
    this.color = Colors.blue,
    this.strokeWidth = 2,
    required this.endLabel,
    required this.startLabel,
  }) : assert(
         startLabel.toLowerCase().trim() != endLabel.toLowerCase().trim(),
         "startLabel and endLabel must not be the same.",
       );
}
