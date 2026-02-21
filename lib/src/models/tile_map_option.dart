import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:pmtiles_map/src/models/drawline_on_point.dart';
import 'package:pmtiles_map/src/models/lat_long.dart';
import 'package:pmtiles_map/src/models/location_result.dart';

typedef MapEventCallback = void Function(dynamic event);

class TileMapOption {
  final LatLong initialCenter;
  final double initialZoom;
  final double initialRotation;
  final double? minZoom;
  final double maxZoom;
  final Color backgroundColor;
  final List<FenceRadius> fenceRadius;
  final void Function(LatLong)? onTap;
  final void Function(LatLong)? onSecondaryTap;
  final void Function(LatLong)? onLongPress;
  final MapEventCallback? onMapEvent;
  final void Function()? onMapReady;
  final Future<void> Function(LatLong, LocationResult)? onTapAndSearch;
  final bool keepAlive;
  final List<Polygon> polygons;
  final List<DrawLineOnPoint> drawLineOn;
  final bool autoDarkMode;
  final bool showUserLocation;
  final bool showZoomControls;
  final bool showScaleBar;
  final bool use3D;
  final String? styleUrl;
  final double initialTilt;
  final bool enableTerrain;
  TileMapOption({
    LatLong? initialCenter,
    this.initialZoom = 13.0,
    this.initialRotation = 0.0,
    this.fenceRadius = const [],
    this.minZoom,
    this.maxZoom = 100,
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.onTap,
    this.onSecondaryTap,
    this.onLongPress,
    this.onMapEvent,
    this.drawLineOn = const [],
    this.onMapReady,
    this.polygons = const [],
    this.keepAlive = false,
    this.onTapAndSearch,
    this.autoDarkMode = true,
    this.showUserLocation = false,
    this.showZoomControls = false,
    this.showScaleBar = false,
    this.use3D = false,
    this.styleUrl,
    this.initialTilt = 0.0,
    this.enableTerrain = false,
  }) : initialCenter = initialCenter ?? LatLong(12.8797, 121.7740);
}

class FenceRadius {
  final double borderWidth;
  final Color color;
  final LatLong center;
  final double radius; // radius in meters
  const FenceRadius({
    this.borderWidth = 1,
    required this.center,
    required this.radius,
    this.color = Colors.blue,
  });
}
