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
  static Polygon _boundingBoxToPolygon(List<String> boundingBox) {
    double south = double.parse(boundingBox[0]);
    double north = double.parse(boundingBox[1]);
    double west = double.parse(boundingBox[2]);
    double east = double.parse(boundingBox[3]);
    final points = [
      LatLng(south, west), // SW corner
      LatLng(north, west), // NW corner
      LatLng(north, east), // NE corner
      LatLng(south, east), // SE corner
      LatLng(south, west), // back to SW to close the polygon
    ];
    return Polygon(points: points);
  }

  static Future<LocationResult> reverseGeoCode(LatLong latlng) async {
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
      'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=$limit',
    );

    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'LumiereCoding/1.0', // Nominatim requires a User-Agent
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to search address');
    }

    final List data = json.decode(response.body);

    return data.map((e) {
      final addr = e['address'] ?? {};

      // Extract coordinates
      LatLong? coordinates;
      if (e['lat'] != null && e['lon'] != null) {
        coordinates = LatLong(
          double.tryParse(e['lat'].toString()) ?? 0,
          double.tryParse(e['lon'].toString()) ?? 0,
        );
      }

      final map = {
        'city':
            addr['county'] ??
            addr['city'] ??
            addr['town'] ??
            addr['residential'],
        'barangay': (() {
          final suburb = addr['suburb'];
          final neighbourhood = addr['neighbourhood'];
          if (suburb != null && neighbourhood != null)
            return '$neighbourhood, $suburb';
          return addr['village'] ??
              addr['quarter'] ??
              addr['hamlet'] ??
              suburb ??
              neighbourhood;
        })(),
        'province': addr['state'],
        'address': e['display_name'],
        'street': addr['road'],
        'region': addr['region'],
        'postalCode': addr['postcode'],
        'country': addr['country'],
        'countryCode': addr['country_code'],
        'latitude': coordinates?.latitude,
        'longitude': coordinates?.longitude,
      };

      return CoordinatedLocationResult.fromMap(map);
    }).toList();
  }
}
