import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';
import 'package:pmtiles_map/pmtiles_map.dart';
import 'package:pmtiles_map/src/models/lat_long.dart' as pm;
import 'package:pmtiles_map/src/pin_marker.dart';

import 'package:pmtiles_map/src/services/api_call.dart';

class PmtilesMapPicker extends StatefulWidget {
  final TileMapPickerOption options;
  final Widget? centerPin;
  final Function(LocationResult, pm.LatLong) callback;
  const PmtilesMapPicker({
    super.key,
    required this.callback,
    required this.options,
    this.centerPin,
  });

  @override
  State<PmtilesMapPicker> createState() => PmtilesMapPickerState();
}

class PmtilesMapPickerState extends State<PmtilesMapPicker>
    with TickerProviderStateMixin {
  late final AnimatedMapController mapController;
  late double currentZoom;
  pm.LatLong? selectedLocation;

  late AnimationController _animController;
  late Animation<double> _pinAnimation;

  @override
  void initState() {
    super.initState();
    mapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCirc,
      cancelPreviousAnimations: true,
    );
    currentZoom = widget.options.initialZoom;
    selectedLocation = widget.options.initialCenter;

    // Animation controller for the pin
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _pinAnimation = Tween<double>(
      begin: 0,
      end: -30,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> animateToCenter(pm.LatLong target, {double? zoom}) async {
    final LatLng dest = LatLng(target.latitude, target.longitude);

    await mapController.animateTo(
      dest: dest,
      zoom: zoom ?? currentZoom,
      duration: mapController.duration,
    );
    final location = pm.LatLong(target.latitude, target.longitude);
    if (selectedLocation == location) return;

    final val = await TileMapGeoCodingService.reverseGeoCode(location);
    widget.callback(val, location);
  }

  Future<void> _updateCenterLocation() async {
    final center = mapController.mapController.camera.center;
    final location = pm.LatLong(center.latitude, center.longitude);
    if (selectedLocation == location) return;

    final val = await TileMapGeoCodingService.reverseGeoCode(location);
    widget.callback(val, location);
  }

  void _onPointerDown() {
    _animController.forward(); // pin goes up
  }

  void _onPointerUp() async {
    _animController.reverse(); // pin drops back
    await _updateCenterLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        FlutterMap(
          mapController: mapController.mapController,
          options: MapOptions(
            initialCenter: LatLng(
              widget.options.initialCenter.latitude,
              widget.options.initialCenter.longitude,
            ),
            initialZoom: currentZoom,
            onPositionChanged: (position, _) {
              setState(() => currentZoom = position.zoom);
            },
            onPointerDown: (event, pos) => _onPointerDown(),
            onPointerUp: (event, pos) => _onPointerUp(),
          ),
          children: [
            TileLayer(
              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              subdomains: ['a', 'b', 'c'],
            ),
            if (widget.options.polygons != null)
              PolygonLayer(polygons: widget.options.polygons!),
          ],
        ),
        // Animated pin
        AnimatedBuilder(
          animation: _pinAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _pinAnimation.value),
              child: child,
            );
          },
          child: SizedBox(
            height: 20,
            width: 20,
            child: widget.centerPin ?? const FlatPinMarker(),
          ),
        ),
        AnimatedBuilder(
          animation: _pinAnimation,
          builder: (context, child) {
            // When the pin goes up, reduce shadow size & opacity
            final scale = 1 - (_pinAnimation.value.abs() / 60);
            return Transform.translate(
              offset: Offset(0, 10), // position shadow below pin
              child: Transform.scale(
                scale: scale.clamp(0.6, 1.0),
                child: Opacity(
                  opacity: scale.clamp(0.4, 1.0),
                  child: Container(
                    width: 20,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Colors.black45, Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
