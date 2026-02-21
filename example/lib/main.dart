import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pmtiles_map/pmtiles_map.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pmtiles Map 3D Example',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blue,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
      ),
      themeMode: ThemeMode.system,
      home: const MapExamplePage(),
    );
  }
}

class MapExamplePage extends StatefulWidget {
  const MapExamplePage({super.key});

  @override
  State<MapExamplePage> createState() => _MapExamplePageState();
}

class _MapExamplePageState extends State<MapExamplePage> {
  final GlobalKey<PmtilesMapState> _mapSelectionKey =
      GlobalKey<PmtilesMapState>();
  bool _use3D = false;

  @override
  void initState() {
    super.initState();
    _use3D =
        kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pmtiles Map 3D (Overture)'),
        actions: [
          IconButton(
            icon: Icon(_use3D ? Icons.view_in_ar : Icons.map),
            onPressed: () => setState(() => _use3D = !_use3D),
            tooltip: 'Toggle 3D Mode',
          ),
          IconButton(
            icon: const Icon(Icons.location_searching),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const MapPickerPage()));
            },
            tooltip: 'Open Map Picker',
          ),
        ],
      ),
      body: Stack(
        children: [
          PmtilesMap(
            key: _mapSelectionKey,
            options: TileMapOption(
              initialCenter: const LatLong(14.5995, 120.9842), // Manila
              initialZoom: 15,
              initialTilt: _use3D ? 60.0 : 0.0,
              use3D: _use3D,
              autoDarkMode: true,
              showUserLocation: true,
              showZoomControls: true,
              showScaleBar: true,
              // Using OpenFreeMap style as a base for 3D extrusions
              styleUrl: _use3D
                  ? "https://tiles.openfreemap.org/styles/liberty"
                  : null,
            ),
            markers: [
              PmTileMapMarker(
                coordinates: const LatLong(14.5995, 120.9842),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tapped Manila Marker!')),
                  );
                },
              ),
            ],
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: _SearchBarOverlay(
              onSelected: (result) {
                _mapSelectionKey.currentState?.animateToCenter(
                  result.coordinates,
                  zoom: 17,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBarOverlay extends StatefulWidget {
  final Function(CoordinatedLocationResult) onSelected;
  const _SearchBarOverlay({required this.onSelected});

  @override
  State<_SearchBarOverlay> createState() => _SearchBarOverlayState();
}

class _SearchBarOverlayState extends State<_SearchBarOverlay> {
  final TextEditingController _controller = TextEditingController();
  List<CoordinatedLocationResult> _results = [];
  Timer? _debounce;

  void _onSearch(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        setState(() => _results.clear());
        return;
      }
      try {
        final results = await TileMapGeoCodingService.searchAddress(query);
        setState(() {
          _results = results;
        });
      } catch (_) {
        setState(() => _results.clear());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            onChanged: _onSearch,
            decoration: InputDecoration(
              hintText: 'Search Manila, Pasig, etc...',
              prefixIcon: const Icon(Icons.search),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        setState(() => _results.clear());
                      },
                    )
                  : null,
            ),
          ),
        ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  color: Colors.black.withOpacity(0.2),
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(result.address ?? 'Unknown'),
                  subtitle: Text(
                    '${result.city ?? ""}, ${result.province ?? ""}',
                  ),
                  onTap: () {
                    widget.onSelected(result);
                    setState(() {
                      _controller.text = result.address ?? "";
                      _results.clear();
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  bool _use3D = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Picker & Search'),
        actions: [
          IconButton(
            icon: Icon(_use3D ? Icons.view_in_ar : Icons.map),
            onPressed: () => setState(() => _use3D = !_use3D),
          ),
        ],
      ),
      body: Stack(
        children: [
          PmtilesMapPicker(
            options: TileMapPickerOption(
              initialCenter: const LatLong(14.5995, 120.9842),
              initialZoom: 16,
              use3D: _use3D,
              initialTilt: _use3D ? 60 : 0,
              showUserLocation: true,
              autoDarkMode: true,
            ),
            currentLocation: const LatLong(14.5995, 120.9842),
            callback: (result) {
              // Location is handled by PmtilesMapPicker's internal state and built-in card.
            },
            showSearch: true,
          ),
        ],
      ),
    );
  }
}
