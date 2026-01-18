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

  TileMapPickerOption({
    LatLong? initialCenter,
    this.pickDelay = 800,
    this.centerPinSize = 20,
    this.initialZoom = 16,
    this.markers,
    this.polygons,
    this.onMapReady,
  }) : initialCenter = initialCenter ?? LatLong(12.8797, 121.7740);
}
