import 'package:pmtiles_map/pmtiles_map.dart';
import 'package:pmtiles_map/src/models/coordinated_location_result.dart';

class LocationResult {
  final String? city;
  final String? barangay;
  final String? province;
  final String? address;
  final String? street;
  final String? region;
  final String? postalCode;
  final String? country;
  final String? countryCode;
  LocationResult({
    this.city,
    this.barangay,
    this.province,
    this.address,
    this.street,
    this.region,
    this.country,
    this.countryCode,
    this.postalCode,
  });
  factory LocationResult.fromJson(Map<String, dynamic> json) {
    return LocationResult(
      city: json['city'] as String?,
      barangay: json['barangay'] as String?,
      province: json['province'] as String?,
      address: json['address'] as String?,
      street: json['street'] as String?,
      region: json['region'] as String?,
      postalCode: json['postalCode'] as String?,
      country: json['country'] as String?,
      countryCode: json['countryCode'] as String?,
    );
  }

  @override
  String toString() => "${toMap()}";

  Map<String, dynamic> toMap() => {
    if (city != null) ...{"city": city},
    if (barangay != null) ...{"barangay": barangay},
    if (province != null) ...{"province": province},
    if (address != null) ...{"address": address},
    if (street != null) ...{"street": street},
    if (region != null) ...{"region": region},
    if (postalCode != null) ...{"postalCode": postalCode},
    if (country != null) ...{"country": country},
    if (countryCode != null) ...{"countryCode": countryCode},
  };
}
