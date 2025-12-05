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
