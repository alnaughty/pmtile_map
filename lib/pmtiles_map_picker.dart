import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';
import 'package:pmtiles_map/pmtiles_map.dart';
import 'package:pmtiles_map/src/models/lat_long.dart' as pm;
import 'package:pmtiles_map/src/new_pin_marker.dart';
import 'package:pmtiles_map/src/pin_marker.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as gl;

typedef CenterAnimationBuilder =
    Widget Function(Widget child, double animationValue);

class PmtilesMapPicker extends StatefulWidget {
  final TileMapPickerOption options;
  final Widget? centerPin;
  final Color pinColor;
  final Widget? searchWidget;
  final Widget? currentLocationWidget;
  final Gradient? pinGradient;
  final Widget Function(List<CoordinatedLocationResult> searchResults)?
  searchResultBuilder;

  final Function(CoordinatedLocationResult) callback;
  final pm.LatLong currentLocation;
  final bool showSearch;
  final CenterAnimationBuilder? centerAnimationBuilder;

  const PmtilesMapPicker({
    super.key,
    this.searchResultBuilder,
    required this.callback,
    this.currentLocationWidget,
    this.searchWidget,
    this.showSearch = true,
    required this.options,
    this.pinColor = Colors.red,
    this.pinGradient,
    required this.currentLocation,
    this.centerAnimationBuilder,
    this.centerPin,
  });

  @override
  State<PmtilesMapPicker> createState() => PmtilesMapPickerState();
}

class PmtilesMapPickerState extends State<PmtilesMapPicker>
    with TickerProviderStateMixin {
  late final AnimatedMapController mapController;
  gl.MapLibreMapController? glController;
  late double currentZoom;
  pm.LatLong? selectedLocation;

  late AnimationController _animController;
  late Animation<double> _pinAnimation;
  late final Animation<double> _centerAnimation;
  late final AnimationController _centerController;
  bool isSearching = false;
  bool _isCameraMoving = false;
  bool _showSearchField = false;
  Timer? _debounce;
  final TextEditingController searchController = TextEditingController();
  List<CoordinatedLocationResult> searchResults = [];

  /// Holds the last resolved picked location result to show in the bottom bar.
  CoordinatedLocationResult? _lastResult;

  bool get is3DSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  // Fixed 3D style URL - computed once at init, no context dependency.
  // No dark mode switching for 3D to ensure stable FutureBuilder rendering.
  late final String _styleUrl =
      widget.options.styleUrl ?? "https://tiles.openfreemap.org/styles/liberty";

  void onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() => searchResults.clear());
        return;
      }

      try {
        final results = await TileMapGeoCodingService.searchAddress(query);
        isSearching = true;
        setState(() => searchResults = results);
      } catch (_) {
        isSearching = false;
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
    _centerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _centerAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_centerController);

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
  void didUpdateWidget(PmtilesMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _debounceTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> animateToCenter(
    pm.LatLong target, {
    double? zoom,
    CoordinatedLocationResult? result,
  }) async {
    if (widget.options.use3D && is3DSupported && glController != null) {
      await glController!.animateCamera(
        gl.CameraUpdate.newLatLngZoom(
          gl.LatLng(target.latitude, target.longitude),
          zoom ?? currentZoom,
        ),
      );
    } else {
      final LatLng dest = LatLng(target.latitude, target.longitude);
      await mapController.animateTo(
        dest: dest,
        zoom: zoom ?? currentZoom,
        duration: mapController.duration,
      );
    }

    if (result != null) {
      // If we already have the full result (e.g. from search), use it directly.
      selectedLocation = result.coordinates;
      _lastResult = result;
      widget.callback(result);
    } else {
      // Otherwise, check if we actually moved or need to resolve metadata.
      if (selectedLocation != null &&
          selectedLocation!.latitude == target.latitude &&
          selectedLocation!.longitude == target.longitude) {
        return;
      }

      selectedLocation = target;
      final val = await TileMapGeoCodingService.reverseGeoCode(target);
      final newResult = CoordinatedLocationResult.fromLocationResult(
        target,
        location: val,
      );
      _lastResult = newResult;
      widget.callback(newResult);
    }

    setState(() {
      isSearching = false;
      searchResults.clear();
      searchController.clear();
      _showSearchField = false;
    });
  }

  Timer? _debounceTimer;

  Future<void> _updateCenterLocation() async {
    _debounceTimer?.cancel();

    _debounceTimer = Timer(
      Duration(milliseconds: widget.options.pickDelay),
      () async {
        pm.LatLong location;
        if (widget.options.use3D && is3DSupported && glController != null) {
          final camera = await glController!.cameraPosition;
          if (camera == null) return;
          location = pm.LatLong(
            camera.target.latitude,
            camera.target.longitude,
          );
        } else {
          final center = mapController.mapController.camera.center;
          location = pm.LatLong(center.latitude, center.longitude);
        }

        if (selectedLocation == location) return;

        selectedLocation = location;
        final val = await TileMapGeoCodingService.reverseGeoCode(location);
        final result = CoordinatedLocationResult.fromLocationResult(
          location,
          location: val,
        );

        widget.callback(result);
        if (mounted) {
          setState(() => _lastResult = result);
        }
      },
    );
  }

  void _onPointerDown() {
    _animController.forward();
    if (widget.centerAnimationBuilder != null) {
      _centerController.repeat(
        min: 0,
        max: 1,
        period: const Duration(seconds: 1),
        reverse: false,
      );
    }
  }

  void _onPointerUp() async {
    _animController.reverse();
    if (widget.centerAnimationBuilder != null) {
      _centerController.stop();
      _centerController.reset();
    }
    await _updateCenterLocation();
  }

  /// Navigate to the user's current device location.
  Future<void> _goToCurrentLocation() async {
    await animateToCenter(widget.currentLocation);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.grey[850]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white54 : Colors.black45;
    final shadowColor = isDark ? Colors.black54 : Colors.black26;

    final map = Stack(
      alignment: Alignment.center,
      children: [
        if (widget.options.use3D && is3DSupported)
          _build3DMap(context)
        else
          fm.FlutterMap(
            mapController: mapController.mapController,
            options: fm.MapOptions(
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
              _buildTileLayer(context),
              if (widget.options.showUserLocation) const CurrentLocationLayer(),
              if (widget.options.polygons != null)
                fm.PolygonLayer(polygons: widget.options.polygons!),
              fm.MarkerLayer(
                markers: [
                  fm.Marker(
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

        // ── pin shadow ──────────────────────────────────────────────────────
        AnimatedBuilder(
          animation: _pinAnimation,
          builder: (context, child) {
            final scale = 1 - (_pinAnimation.value.abs() / 60);
            return Transform.translate(
              offset: Offset(0, widget.options.centerPinSize / 2),
              child: Transform.scale(
                scale: scale.clamp(0.6, 1.0),
                child: Opacity(
                  opacity: scale.clamp(0.4, 1),
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

        // ── center pin ──────────────────────────────────────────────────────
        AnimatedBuilder(
          animation: _pinAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _pinAnimation.value),
              child: child,
            );
          },
          child: OverflowBox(
            maxHeight: widget.options.centerPinSize * 2,
            maxWidth: widget.options.centerPinSize * 2,
            child: SizedBox(
              height: widget.options.centerPinSize,
              width: widget.options.centerPinSize,
              child: CustomMapMarker(
                centerWidget: _buildCenterPin(),
                color: widget.pinColor,
                gradient: widget.pinGradient,
              ),
            ),
          ),
        ),

        // ── top bar: search + my-location ───────────────────────────────────
        Positioned(
          top: 20,
          right: 20,
          left: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Search area
                  if (widget.showSearch) ...[
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _showSearchField
                            ? AnimatedContainer(
                                width: _showSearchField ? double.infinity : 0,
                                duration: const Duration(milliseconds: 600),
                                height: 60,
                                key: const ValueKey('search_open'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                alignment: AlignmentDirectional.centerStart,
                                decoration: BoxDecoration(
                                  color: backgroundColor,
                                  borderRadius: BorderRadius.circular(100),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 10,
                                      color: shadowColor.withOpacity(0.2),
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller: searchController,
                                  autofocus: true,

                                  onChanged: onSearchChanged,
                                  decoration: InputDecoration(
                                    alignLabelWithHint: true,
                                    hintText: 'Search for a place...',
                                    hintStyle: TextStyle(color: hintColor),
                                    border: InputBorder.none,
                                    icon: Icon(
                                      Icons.search,
                                      color: theme.disabledColor,
                                    ),

                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        searchController.clear();
                                        onSearchChanged('');
                                        setState(
                                          () => _showSearchField = false,
                                        );
                                      },
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 18,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(
                                key: ValueKey('search_closed'),
                              ),
                      ),
                    ),
                    if (!_showSearchField) ...[
                      // Search icon button (collapsed state)
                      _MapControlButton(
                        icon: Icons.search,
                        backgroundColor: backgroundColor,
                        iconColor: textColor,
                        shadowColor: shadowColor,
                        onTap: () => setState(() => _showSearchField = true),
                      ),
                    ],
                  ],
                  const SizedBox(width: 8),
                  // Find my location button
                  _MapControlButton(
                    icon: Icons.my_location,
                    backgroundColor: backgroundColor,
                    iconColor: textColor,
                    shadowColor: shadowColor,
                    onTap: _goToCurrentLocation,
                  ),
                ],
              ),

              // Search results dropdown
              if (isSearching && searchResults.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        color: shadowColor.withOpacity(0.3),
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: textColor.withOpacity(0.1)),
                      itemBuilder: (context, index) {
                        final result = searchResults[index];
                        return ListTile(
                          leading: Icon(
                            Icons.location_on,
                            color: theme.primaryColor,
                          ),
                          title: Text(
                            result.address ?? 'Unknown',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            [
                              result.barangay,
                              result.city,
                              result.province,
                            ].where((e) => e != null).join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textColor.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          onTap: () async {
                            await animateToCenter(
                              result.coordinates,
                              result: result,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── bottom card: location details + Select Location button ──────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomCard(
            context,
            theme: theme,
            isDark: isDark,
            backgroundColor: backgroundColor,
            textColor: textColor,
            shadowColor: shadowColor,
          ),
        ),
      ],
    );

    if (widget.options.showZoomControls) {
      return Stack(
        children: [
          map,
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: 'picker_zoom_in',
                  mini: true,
                  onPressed: () {
                    if (widget.options.use3D &&
                        is3DSupported &&
                        glController != null) {
                      glController!.animateCamera(gl.CameraUpdate.zoomIn());
                    } else {
                      mapController.animateTo(
                        zoom: currentZoom + 1,
                        duration: const Duration(milliseconds: 300),
                      );
                    }
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'picker_zoom_out',
                  mini: true,
                  onPressed: () {
                    if (widget.options.use3D &&
                        is3DSupported &&
                        glController != null) {
                      glController!.animateCamera(gl.CameraUpdate.zoomOut());
                    } else {
                      mapController.animateTo(
                        zoom: currentZoom - 1,
                        duration: const Duration(milliseconds: 300),
                      );
                    }
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

  Widget _buildBottomCard(
    BuildContext context, {
    required ThemeData theme,
    required bool isDark,
    required Color backgroundColor,
    required Color textColor,
    required Color shadowColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            color: shadowColor.withOpacity(0.25),
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          if (_lastResult != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_pin, color: theme.primaryColor, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_lastResult!.address != null)
                        Text(
                          _lastResult!.address!,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          _lastResult!.barangay,
                          _lastResult!.city,
                          _lastResult!.province,
                        ].where((e) => e != null && e.isNotEmpty).join(', '),
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_lastResult!.coordinates.latitude.toStringAsFixed(6)}, '
                        '${_lastResult!.coordinates.longitude.toStringAsFixed(6)}',
                        style: TextStyle(
                          color: textColor.withOpacity(0.4),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ] else ...[
            Row(
              children: [
                Icon(
                  Icons.touch_app,
                  color: textColor.withOpacity(0.4),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Drag the map to pick a location',
                  style: TextStyle(
                    color: textColor.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Select Location button
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                final result =
                    _lastResult ?? await _resolveCurrentCenterResult();
                widget.callback(result);
                if (context.mounted) Navigator.of(context).pop(result);
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Select Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Resolves the center coordinate to a [CoordinatedLocationResult] on-demand
  /// (used when Select Location is tapped before any drag has happened).
  Future<CoordinatedLocationResult> _resolveCurrentCenterResult() async {
    pm.LatLong location;
    if (widget.options.use3D && is3DSupported && glController != null) {
      final camera = await glController!.cameraPosition;
      location = camera != null
          ? pm.LatLong(camera.target.latitude, camera.target.longitude)
          : widget.currentLocation;
    } else {
      final center = mapController.mapController.camera.center;
      location = pm.LatLong(center.latitude, center.longitude);
    }
    final val = await TileMapGeoCodingService.reverseGeoCode(location);
    return CoordinatedLocationResult.fromLocationResult(
      location,
      location: val,
    );
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
      onMapCreated: (controller) {
        glController = controller;
      },
      myLocationEnabled: false,
      trackCameraPosition: true,
      onCameraMove: (pos) {
        currentZoom = pos.zoom;
        // Trigger pin-lift animation once when dragging begins.
        if (!_isCameraMoving) {
          _isCameraMoving = true;
          _onPointerDown();
        }
      },
      onCameraIdle: () {
        // Camera stopped – reverse animation and pick coordinates.
        if (_isCameraMoving) {
          _isCameraMoving = false;
          _onPointerUp();
        }
      },
    );
  }

  Widget _buildCenterPin() {
    final child =
        widget.centerPin ??
        Container(
          width: widget.options.centerPinSize / 4,
          height: widget.options.centerPinSize / 4,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        );

    final builder = widget.centerAnimationBuilder;
    if (builder == null) return child;

    return AnimatedBuilder(
      animation: _centerAnimation,
      builder: (_, _) {
        return builder(child, _centerAnimation.value);
      },
    );
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
          -0.2126, -0.7152, -0.0722, 0, 255, // Red
          -0.2126, -0.7152, -0.0722, 0, 255, // Green
          -0.2126, -0.7152, -0.0722, 0, 255, // Blue
          0, 0, 0, 1, 0, // Alpha
        ]),
        child: tileLayer,
      );
    }
    return tileLayer;
  }
}

/// Small circular icon button used in the map top bar.
class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final Color shadowColor;
  final VoidCallback onTap;

  const _MapControlButton({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.shadowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              color: shadowColor.withOpacity(0.2),
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}
