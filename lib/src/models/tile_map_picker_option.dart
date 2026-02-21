import 'package:pmtiles_map/src/models/lat_long.dart';
import 'package:flutter_map/flutter_map.dart';

class TileMapPickerOption {
  final LatLong initialCenter;
  final double initialZoom;
  final List<Marker>? markers;
  final double centerPinSize;
  final List<Polygon>? polygons;
  final int pickDelay;

  final void Function(MapController mapController)? onMapReady;
  final bool autoDarkMode;
  final bool showUserLocation;
  final bool showZoomControls;
  final bool showScaleBar;

  // 3D Options
  final bool use3D;
  final String? styleUrl;
  final double initialTilt;
  final bool enableTerrain;

  TileMapPickerOption({
    LatLong? initialCenter,
    this.pickDelay = 800,
    this.centerPinSize = 45,
    this.initialZoom = 16,
    this.markers,
    this.polygons,
    this.onMapReady,
    this.autoDarkMode = true,
    this.showUserLocation = false,
    this.showZoomControls = false,
    this.showScaleBar = false,
    this.use3D = false,
    this.styleUrl,
    this.initialTilt = 0,
    this.enableTerrain = false,
  }) : initialCenter = initialCenter ?? LatLong(12.8797, 121.7740);
}
