import 'dart:math' show cos, pow;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';
import 'package:pmtiles_map/src/models/drawline_on_point.dart';
import 'package:pmtiles_map/src/models/tile_map_option.dart';
export 'package:pmtiles_map/src/models/lat_long.dart';
import 'package:pmtiles_map/src/models/lat_long.dart' as pm;
import 'package:pmtiles_map/src/pin_marker.dart';
export 'package:pmtiles_map/src/models/tile_map_option.dart';
export 'package:pmtiles_map/src/models/location_result.dart';
import 'package:pmtiles_map/src/services/api_call.dart';
export 'package:pmtiles_map/src/services/api_call.dart';
export 'package:flutter_map/src/layer/polyline_layer/polyline_layer.dart';
export 'package:pmtiles_map/src/models/drawline_on_point.dart';
export 'package:pmtiles_map/pmtiles_map_picker.dart';
export 'package:pmtiles_map/src/models/tile_map_picker_option.dart';
export 'package:pmtiles_map/src/models/coordinated_location_result.dart';

class PmtilesMap extends StatefulWidget {
  const PmtilesMap({
    super.key,
    this.markers,
    this.polygons,
    required this.options,
  });
  final TileMapOption options;
  final List<PmTileMapMarker>? markers;
  final List<Polygon>? polygons;

  @override
  State<PmtilesMap> createState() => PmtilesMapState();
}

class PmtilesMapState extends State<PmtilesMap> with TickerProviderStateMixin {
  late final opts = widget.options;
  late double currentZoom = opts.initialZoom;
  late final AnimatedMapController mapController;
  List<Polyline> polylines = [];
  List<Marker> polylineCenterMarkers = [];
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((v) async {
      await _generatePolylines();
    });
    super.initState();
    mapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCirc,
      cancelPreviousAnimations: true,
    );
  }

  @override
  void dispose() {
    super.dispose();
    mapController.dispose();
  }

  Future<void> animateToCenter(pm.LatLong target, {double? zoom}) async {
    final LatLng dest = LatLng(target.latitude, target.longitude);

    await mapController.animateTo(
      dest: dest,
      zoom: zoom ?? currentZoom,
      duration: mapController.duration,
    );
  }

  Future<void> _generatePolylines() async {
    if (widget.options.drawLineOn.isEmpty) return;

    for (final DrawLineOnPoint point in widget.options.drawLineOn) {
      final line = await TileMapGeoCodingService.fetchRoute(
        pointA: point.start,
        pointB: point.end,
        color: point.color,
        strokeWidth: point.strokeWidth,
      );

      if (line != null) {
        polylines.add(line);

        // --- NEW: center marker ---
        final center = getPolylineCenter(line.points);
        polylineCenterMarkers.addAll([
          Marker(
            point: LatLng(point.start.latitude, point.start.longitude),
            alignment: Alignment.topCenter,
            child: Tooltip(
              message: point.startLabel,
              child: point.startMarker ?? FlatPinMarker(),
            ),
          ),
          Marker(
            point: LatLng(point.end.latitude, point.end.longitude),
            alignment: Alignment.topCenter,
            child: Tooltip(
              message: point.endLabel,
              child: point.endMarker ?? FlatPinMarker(),
            ),
          ),
        ]);

        if (mounted) setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController.mapController,
      options: MapOptions(
        initialCenter: LatLng(
          widget.options.initialCenter.latitude,
          widget.options.initialCenter.longitude,
        ),
        initialZoom: widget.options.initialZoom,
        minZoom: opts.minZoom,
        maxZoom: opts.maxZoom,
        onTap: (tapPosition, latlng) async {
          if (widget.options.onTapAndSearch != null) {
            final result = await TileMapGeoCodingService.reverseGeoCode(
              pm.LatLong(latlng.latitude, latlng.longitude),
            );
            await widget.options.onTapAndSearch!(
              pm.LatLong(latlng.latitude, latlng.longitude),
              result,
            );
          }
          if (widget.options.onTap != null) {
            widget.options.onTap!(
              pm.LatLong(latlng.latitude, latlng.longitude),
            );
          }
        },
        onSecondaryTap: opts.onSecondaryTap == null
            ? null
            : (tapPos, latlng) {
                opts.onSecondaryTap!(
                  pm.LatLong(latlng.latitude, latlng.longitude),
                );
              },
        onLongPress: opts.onLongPress == null
            ? null
            : (tapPos, latlng) {
                opts.onLongPress!(
                  pm.LatLong(latlng.latitude, latlng.longitude),
                );
              },
        onMapReady: opts.onMapReady,
        keepAlive: opts.keepAlive,
        onPositionChanged: (MapCamera position, bool _) {
          setState(() {
            currentZoom = position.zoom;
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
          subdomains: ['a', 'b', 'c'],
        ),
        PolylineLayer(polylines: polylines),

        CircleLayer(
          circles: widget.options.fenceRadius
              .map(
                (fence) => CircleMarker(
                  borderStrokeWidth: fence.borderWidth,
                  borderColor: fence.color,
                  color: fence.color.withOpacity(.2),
                  point: LatLng(fence.center.latitude, fence.center.longitude),
                  radius: metersToPixels(
                    fence.radius,
                    LatLng(fence.center.latitude, fence.center.longitude),
                    currentZoom,
                  ),
                ),
              )
              .toList(),
        ),
        MarkerLayer(markers: polylineCenterMarkers),
        if (widget.polygons != null) PolygonLayer(polygons: widget.polygons!),
        if (widget.markers != null)
          MarkerLayer(
            markers: (widget.markers ?? [])
                .map(
                  (marker) => Marker(
                    point: LatLng(
                      marker.coordinates.latitude,
                      marker.coordinates.longitude,
                    ),
                    child: marker.child,
                    height: marker.height,
                    width: marker.width,
                    alignment: marker.alignment,
                    rotate: marker.rotate,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  double metersToPixels(double meters, LatLng lat, double zoom) {
    // Earth’s circumference in meters at the equator
    const double earthCircumference = 40075016.686;
    final latitudeRadians = lat.latitude * pi / 180;
    final metersPerPixel =
        earthCircumference * cos(latitudeRadians) / pow(2, zoom + 8);
    return meters / metersPerPixel;
  }

  LatLng getPolylineCenter(List<LatLng> points) {
    double lat = 0;
    double lng = 0;

    for (final p in points) {
      lat += p.latitude;
      lng += p.longitude;
    }

    lat /= points.length;
    lng /= points.length;

    return LatLng(lat, lng);
  }
}

class PmTileMapMarker extends Marker {
  final pm.LatLong coordinates;
  const PmTileMapMarker({
    super.point = const LatLng(0, 0),
    required super.child,
    super.alignment,
    super.height,
    super.rotate,
    super.width,
    super.key,
    pm.LatLong? coordinates,
  }) : coordinates = coordinates ?? const pm.LatLong(0, 0);
}
