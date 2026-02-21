import 'dart:convert';
import 'dart:math' show pi, sin, cos, sqrt, atan2;

import 'package:flutter/material.dart' show Colors, Color;
import 'package:flutter_map/flutter_map.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart'
    show decodePolyline;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:pmtiles_map/pmtiles_map.dart';
import 'package:pmtiles_map/src/models/coordinated_location_result.dart';

class TileMapGeoCodingService {
  static Future<LocationResult> reverseGeoCode(LatLong latlng) async {
    try {
      final url = Uri.parse(
        "https://nominatim.openstreetmap.org/reverse?lat=${latlng.latitude}&lon=${latlng.longitude}&format=json&addressdetails=1",
      );
      final response = await http.get(
        url,
        headers: {"User-Agent": "LumiereCoding"},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addr = data['address'] ?? {};
        String? barangay;
        final suburb = addr['suburb'];
        final neighbourhood = addr['neighbourhood'];
        if (suburb != null && neighbourhood != null) {
          barangay = '$neighbourhood, $suburb';
        } else {
          barangay =
              addr['village'] ??
              addr['quarter'] ??
              addr['hamlet'] ??
              suburb ??
              neighbourhood;
        }

        return LocationResult(
          city:
              addr['county'] ??
              addr['city'] ??
              addr['town'] ??
              addr['residential'],
          barangay: barangay,
          province: addr['state'],
          address: data['display_name'],
          street: addr['road'],
          region: addr['region'],
          country: addr['country'],
          postalCode: addr['postcode'],
          countryCode: addr['country_code'],
        );
      }
    } catch (_) {
      // Network / CORS errors (common on web) – return a coordinate-only fallback.
      return LocationResult(
        address:
            '${latlng.latitude.toStringAsFixed(6)}, ${latlng.longitude.toStringAsFixed(6)}',
      );
    }

    return LocationResult();
  }

  double getDistanceInKm({required LatLong pointA, required LatLong pointB}) {
    const R = 6371; // Earth's radius in km

    double toRad(double degree) => degree * pi / 180;

    final lat1 = pointA.latitude;
    final lon1 = pointA.longitude;
    final lat2 = pointB.latitude;
    final lon2 = pointB.longitude;

    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    final distance = R * c;

    return distance;
  }

  bool isWithinRadius({
    required LatLong center,
    required LatLong target,
    required double radiusKm,
  }) {
    final distance = getDistanceInKm(pointA: center, pointB: target);

    return distance <= radiusKm;
  }

  static Future<Polyline>? fetchRoute({
    required LatLong pointA,
    required LatLong pointB,
    Color color = Colors.blue,
    double strokeWidth = 2,
  }) async {
    final url =
        'https://router.project-osrm.org/route/v1/driving/${pointA.longitude},${pointA.latitude};${pointB.longitude},${pointB.latitude}?overview=full&geometries=polyline';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch route');
    }
    final data = jsonDecode(response.body);
    final route = data['routes'][0];

    // Decode polyline (precision 5 for OSRM polyline5)
    final decodedCoords = decodePolyline(route['geometry']);

    // Convert to LatLng list for flutter_map
    final routePoints = decodedCoords
        .map((p) => LatLng(p[0].toDouble(), p[1].toDouble()))
        .toList();

    return Polyline(
      points: routePoints,
      color: color,
      strokeWidth: strokeWidth,
    );
  }

  static Future<List<CoordinatedLocationResult>> searchAddress(
    String query, {
    int limit = 10,
  }) async {
    if (query.isEmpty) return [];

    final url = Uri.parse(
      'https://photon.komoot.io/api/?q=${Uri.encodeComponent(query)}&limit=$limit',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to search address');
    }

    final data = json.decode(response.body);
    final List features = data['features'] ?? [];

    return features.map((feature) {
      final props = feature['properties'] ?? {};
      final geometry = feature['geometry'] ?? {};
      final coords = geometry['coordinates'] as List?;

      // Extract coordinates (Photon returns [lon, lat])
      LatLong? coordinates;
      if (coords != null && coords.length >= 2) {
        coordinates = LatLong(
          (coords[1] as num).toDouble(),
          (coords[0] as num).toDouble(),
        );
      }

      final map = {
        'city': props['city'] ?? props['town'] ?? props['village'],
        'barangay': props['district'] ?? props['locality'] ?? props['suburb'],
        'province': props['state'],
        'address': [
          props['name'],
          props['street'],
          props['housenumber'],
          props['district'],
          props['city'],
          props['state'],
          props['country'],
        ].where((e) => e != null).join(', '),
        'street': props['street'],
        'region': props['state'],
        'postalCode': props['postcode'],
        'country': props['country'],
        'countryCode': props['countrycode'],
        'lat': coordinates?.latitude,
        'lon': coordinates?.longitude,
      };

      return CoordinatedLocationResult.fromMap(map);
    }).toList();
  }
}
