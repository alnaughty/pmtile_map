import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';
import 'package:pmtiles_map/src/models/drawline_on_point.dart';
import 'package:pmtiles_map/src/models/tile_map_option.dart';
import 'package:pmtiles_map/src/models/lat_long.dart' as pm;
import 'package:pmtiles_map/src/pin_marker.dart';
import 'package:pmtiles_map/src/services/api_call.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as gl;

export 'package:pmtiles_map/src/models/lat_long.dart';
export 'package:pmtiles_map/src/models/tile_map_option.dart';
export 'package:pmtiles_map/src/models/location_result.dart';
export 'package:pmtiles_map/src/services/api_call.dart';
export 'package:flutter_map/src/layer/polyline_layer/polyline_layer.dart';
export 'package:pmtiles_map/src/models/drawline_on_point.dart';
export 'package:pmtiles_map/pmtiles_map_picker.dart';
export 'package:pmtiles_map/src/models/tile_map_picker_option.dart';
export 'package:pmtiles_map/src/models/coordinated_location_result.dart';
export 'package:pmtiles_map/src/new_pin_marker.dart';

class PmtilesMap extends StatefulWidget {
  const PmtilesMap({
    super.key,
    this.markers,
    this.polygons,
    required this.options,
  });
  final TileMapOption options;
  final List<PmTileMapMarker>? markers;
  final List<fm.Polygon>? polygons;

  @override
  State<PmtilesMap> createState() => PmtilesMapState();
}

class PmtilesMapState extends State<PmtilesMap> with TickerProviderStateMixin {
  late final opts = widget.options;
  late double currentZoom = opts.initialZoom;
  late final AnimatedMapController mapController;
  gl.MapLibreMapController? glController;

  // Fixed 3D style URL - computed once at init.
  late final String _styleUrl =
      widget.options.styleUrl ?? "https://tiles.openfreemap.org/styles/liberty";

  List<fm.Polyline> polylines = [];
  List<fm.Marker> polylineCenterMarkers = [];

  bool get is3DSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((v) async {
      await _generatePolylines();
    });
    super.initState();
    currentZoom = widget.options.initialZoom;
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

  @override
  void didUpdateWidget(PmtilesMap oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  Future<void> animateToCenter(pm.LatLong target, {double? zoom}) async {
    if (widget.options.use3D && is3DSupported && glController != null) {
      await glController!.animateCamera(
        gl.CameraUpdate.newLatLngZoom(
          gl.LatLng(target.latitude, target.longitude),
          zoom ?? currentZoom,
        ),
      );
      return;
    }

    final LatLng dest = LatLng(target.latitude, target.longitude);
    await mapController.animateTo(
      dest: dest,
      zoom: zoom ?? currentZoom,
      duration: mapController.duration,
    );
  }

  Future<void> fitBounds(
    fm.LatLngBounds bounds, {
    double padding = 12.0,
  }) async {
    if (widget.options.use3D && is3DSupported && glController != null) {
      await glController!.animateCamera(
        gl.CameraUpdate.newLatLngBounds(
          gl.LatLngBounds(
            southwest: gl.LatLng(
              bounds.southWest.latitude,
              bounds.southWest.longitude,
            ),
            northeast: gl.LatLng(
              bounds.northEast.latitude,
              bounds.northEast.longitude,
            ),
          ),
          left: padding,
          top: padding,
          right: padding,
          bottom: padding,
        ),
      );
      return;
    }

    await mapController.animatedFitCamera(
      cameraFit: fm.CameraFit.bounds(
        bounds: bounds,
        padding: EdgeInsets.all(padding),
      ),
      duration: mapController.duration,
      curve: Curves.easeInOutCirc,
    );
  }

  Future<void> fitPoints(
    List<pm.LatLong> points, {
    double padding = 12.0,
  }) async {
    if (points.isEmpty) return;
    final latLngs = points.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final bounds = fm.LatLngBounds.fromPoints(latLngs);
    await fitBounds(bounds, padding: padding);
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
        polylineCenterMarkers.addAll([
          fm.Marker(
            point: LatLng(point.start.latitude, point.start.longitude),
            alignment: Alignment.topCenter,
            child: Tooltip(
              message: point.startLabel,
              child: point.startMarker ?? FlatPinMarker(),
            ),
          ),
          fm.Marker(
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
    if (widget.options.use3D && is3DSupported) {
      return _build3DMap(context);
    }

    final map = fm.FlutterMap(
      mapController: mapController.mapController,
      options: fm.MapOptions(
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
        onMapReady: opts.onMapReady,
        keepAlive: opts.keepAlive,
        onPositionChanged: (fm.MapCamera position, bool _) {
          setState(() {
            currentZoom = position.zoom;
          });
        },
      ),
      children: [
        _buildTileLayer(context),
        if (widget.options.showUserLocation) const CurrentLocationLayer(),
        fm.PolylineLayer(polylines: polylines),
        fm.CircleLayer(
          circles: widget.options.fenceRadius
              .map(
                (fence) => fm.CircleMarker(
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
        fm.MarkerLayer(markers: polylineCenterMarkers),
        if (widget.polygons != null)
          fm.PolygonLayer(polygons: widget.polygons!),
        if (widget.markers != null)
          fm.MarkerLayer(
            markers: (widget.markers ?? [])
                .map(
                  (marker) => fm.Marker(
                    point: LatLng(
                      marker.coordinates.latitude,
                      marker.coordinates.longitude,
                    ),
                    child: marker.onTap != null
                        ? GestureDetector(
                            onTap: marker.onTap,
                            child: marker.child,
                          )
                        : marker.child,
                    height: marker.height,
                    width: marker.width,
                    alignment: marker.alignment,
                    rotate: marker.rotate,
                  ),
                )
                .toList(),
          ),
        // if (widget.options.showScaleBar)
        //   const fm.SimpleAttributionWidget(
        //     source: Text('© OpenStreetMap contributors'),
        //   ),
      ],
    );

    if (widget.options.showZoomControls) {
      return Stack(
        children: [
          map,
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'zoom_in',
                  mini: true,
                  onPressed: () {
                    mapController.animateTo(
                      zoom: currentZoom + 1,
                      duration: const Duration(milliseconds: 300),
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'zoom_out',
                  mini: true,
                  onPressed: () {
                    mapController.animateTo(
                      zoom: currentZoom - 1,
                      duration: const Duration(milliseconds: 300),
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return map;
  }

  Widget _build3DMap(BuildContext context) {
    return gl.MapLibreMap(
      initialCameraPosition: gl.CameraPosition(
        target: gl.LatLng(
          widget.options.initialCenter.latitude,
          widget.options.initialCenter.longitude,
        ),
        zoom: widget.options.initialZoom,
        tilt: widget.options.initialTilt,
      ),
      styleString: _styleUrl,
      onMapCreated: (controller) async {
        glController = controller;
        await _registerMapIcons();
        if (widget.options.onMapReady != null) widget.options.onMapReady!();
      },
      myLocationEnabled: false,
      trackCameraPosition: true,
      onCameraMove: (pos) {
        currentZoom = pos.zoom;
      },
    );
  }

  Future<void> _registerMapIcons() async {
    if (glController == null) return;
    final List<String> icons = [
      'atm.png',
      'ferry_terminal.png',
      'gate.png',
      'office.png',
      'pin.png',
      'recycling.png',
    ];

    for (final icon in icons) {
      final String name = icon.split('.').first;
      // In Flutter Web, package assets are prefixed with 'packages/package_name/'.
      final String assetPath = 'packages/pmtiles_map/assets/$icon';
      try {
        final ByteData bytes = await rootBundle.load(assetPath);
        final Uint8List list = bytes.buffer.asUint8List();
        await glController!.addImage(name, list);
        if (kDebugMode) {
          print('Successfully registered MapLibre icon: $name ($assetPath)');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Failed to register MapLibre icon $name from $assetPath: $e');
        }
      }
    }
  }

  double metersToPixels(double meters, LatLng lat, double zoom) {
    const double earthCircumference = 40075016.686;
    final latitudeRadians = lat.latitude * math.pi / 180;
    final metersPerPixel =
        earthCircumference * math.cos(latitudeRadians) / math.pow(2, zoom + 8);
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

  Widget _buildTileLayer(BuildContext context) {
    final isDarkMode =
        widget.options.autoDarkMode &&
        Theme.of(context).brightness == Brightness.dark;
    final tileLayer = fm.TileLayer(
      urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
      subdomains: const ['a', 'b', 'c'],
      tileProvider: CancellableNetworkTileProvider(),
    );
    if (isDarkMode) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -0.2126,
          -0.7152,
          -0.0722,
          0,
          255,
          -0.2126,
          -0.7152,
          -0.0722,
          0,
          255,
          -0.2126,
          -0.7152,
          -0.0722,
          0,
          255,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: tileLayer,
      );
    }
    return tileLayer;
  }
}

class PmTileMapMarker extends fm.Marker {
  final pm.LatLong coordinates;
  final VoidCallback? onTap;
  PmTileMapMarker({
    super.point = const LatLng(0, 0),
    required super.child,
    super.alignment,
    super.height,
    super.rotate,
    super.width,
    super.key,
    this.onTap,
    pm.LatLong? coordinates,
  }) : coordinates = coordinates ?? const pm.LatLong(0, 0);
}
