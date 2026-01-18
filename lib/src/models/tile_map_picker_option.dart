import 'package:pmtiles_map/src/models/lat_long.dart';
import 'package:flutter_map/flutter_map.dart';

class TileMapPickerOption {
  final LatLong initialCenter;
  final bool enableSearch;
  final double initialZoom;
  final List<Marker>? markers;

  final List<Polygon>? polygons;

  final void Function(MapController mapController)? onMapReady;

  TileMapPickerOption({
    LatLong? initialCenter,
    this.initialZoom = 16,
    this.enableSearch = false,
    this.markers,
    this.polygons,
    this.onMapReady,
  }) : initialCenter = initialCenter ?? LatLong(12.8797, 121.7740);
}
