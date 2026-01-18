import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';
import 'package:pmtiles_map/pmtiles_map.dart';
import 'package:pmtiles_map/src/models/coordinated_location_result.dart';
import 'package:pmtiles_map/src/models/lat_long.dart' as pm;
import 'package:pmtiles_map/src/pin_marker.dart';

import 'package:pmtiles_map/src/services/api_call.dart';

class PmtilesMapPicker extends StatefulWidget {
  final TileMapPickerOption options;
  final Widget? centerPin;
  final Function(CoordinatedLocationResult) callback;
  final pm.LatLong currentLocation;
  const PmtilesMapPicker({
    super.key,
    required this.callback,
    required this.options,
    required this.currentLocation,
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
  bool isSearching = false;
  Timer? _debounce;
  final TextEditingController searchController = TextEditingController();
  List<CoordinatedLocationResult> searchResults = [];
  void onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() => searchResults.clear());
        return;
      }

      try {
        final results = await TileMapGeoCodingService.searchAddress(query);
        setState(() => searchResults = results);
      } catch (_) {
        setState(() => searchResults.clear());
      }
    });
  }

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
    widget.callback(
      CoordinatedLocationResult.fromLocationResult(location, location: val),
    );
  }

  Future<void> _updateCenterLocation() async {
    final center = mapController.mapController.camera.center;
    final location = pm.LatLong(center.latitude, center.longitude);
    if (selectedLocation == location) return;

    final val = await TileMapGeoCodingService.reverseGeoCode(location);
    widget.callback(
      CoordinatedLocationResult.fromLocationResult(location, location: val),
    );
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[850]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white54 : Colors.black45;
    final shadowColor = isDark ? Colors.black54 : Colors.black26;

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
            MarkerLayer(
              markers: [
                Marker(
                  point: LatLng(
                    widget.currentLocation.latitude,
                    widget.currentLocation.longitude,
                  ),
                  child: FlatPinMarker(
                    color: Colors.blue,
                    highlightColor: const Color.fromARGB(255, 99, 179, 245),
                  ),
                ),
              ],
            ),
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
                        colors: [
                          Colors.white,
                          Colors.black45,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.options.enableSearch) ...{
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: isSearching
                      ? MediaQuery.sizeOf(context).width.clamp(100, 400)
                      : 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 4,
                        color: shadowColor,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          isSearching ? Icons.search : Icons.search_outlined,
                          color: textColor,
                        ),
                        onPressed: () {
                          setState(() => isSearching = !isSearching);
                          if (!isSearching) {
                            searchController.clear();
                            searchResults.clear();
                          }
                        },
                      ),
                      if (isSearching)
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: onSearchChanged,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              hintText: 'Search address',
                              hintStyle: TextStyle(color: hintColor),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      if (isSearching)
                        IconButton(
                          icon: Icon(Icons.clear, color: textColor),
                          onPressed: () {
                            searchController.clear();
                            setState(() => searchResults.clear());
                          },
                        ),
                    ],
                  ),
                ),

                if (isSearching && searchResults.isNotEmpty) ...{
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 4,
                          color: shadowColor,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final result = searchResults[index];
                        return ListTile(
                          title: Text(
                            result.address ?? 'Unknown',
                            style: TextStyle(color: textColor),
                          ),
                          subtitle: Text(
                            [
                              result.barangay,
                              result.city,
                              result.province,
                            ].where((e) => e != null).join(', '),
                            style: TextStyle(color: textColor.withOpacity(0.7)),
                          ),
                          onTap: () async {
                            searchController.text = result.address ?? '';
                            searchResults.clear();

                            setState(() => isSearching = false);
                            widget.callback(
                              CoordinatedLocationResult.fromLocationResult(
                                result.coordinates!,
                                location: result,
                              ),
                            );
                            print("CALLING TAP");
                          },
                        );
                      },
                    ),
                  ),
                },
              ],
            ),
          ),
        },
      ],
    );
  }
}
