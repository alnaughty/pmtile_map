import 'package:pmtiles_map/pmtiles_map.dart';

class CoordinatedLocationResult extends LocationResult {
  final LatLong coordinates;
  CoordinatedLocationResult({
    required this.coordinates,
    super.city,
    super.barangay,
    super.province,
    super.address,
    super.street,
    super.region,
    super.postalCode,
    super.country,
    super.countryCode,
  });
  factory CoordinatedLocationResult.fromLocationResult(
    LatLong coordinates, {
    LocationResult? location,
  }) {
    return CoordinatedLocationResult(
      coordinates: coordinates,
      city: location?.city,
      barangay: location?.barangay,
      province: location?.province,
      address: location?.address,
      street: location?.street,
      region: location?.region,
      postalCode: location?.postalCode,
      country: location?.country,
      countryCode: location?.countryCode,
    );
  }
  factory CoordinatedLocationResult.fromMap(Map<String, dynamic> map) {
    final lat = double.tryParse(map['lat']?.toString() ?? '') ?? 0.0;
    final lon = double.tryParse(map['lon']?.toString() ?? '') ?? 0.0;
    LatLong coords = LatLong(lat, lon);

    return CoordinatedLocationResult(
      coordinates: coords,
      city: map['city'] as String?,
      barangay: map['barangay'] as String?,
      province: map['province'] as String?,
      address: map['address'] as String?,
      street: map['street'] as String?,
      region: map['region'] as String?,
      postalCode: map['postalCode'] as String?,
      country: map['country'] as String?,
      countryCode: map['countryCode'] as String?,
    );
  }
  LocationResult toLocationResult() {
    return LocationResult(
      city: city,
      barangay: barangay,
      province: province,
      address: address,
      street: street,
      region: region,
      postalCode: postalCode,
      country: country,
      countryCode: countryCode,
    );
  }

  factory CoordinatedLocationResult.fromJson(Map<String, dynamic> json) =>
      CoordinatedLocationResult.fromMap(json);
  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map.addAll({
      'latitude': coordinates.latitude,
      'longitude': coordinates.longitude,
    });
    return map;
  }
}
