import 'package:latlong2/latlong.dart';
// import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';

extension PolylineDecoder on List<List<num>> {
  List<LatLng> toLatLng() =>
      map((p) => LatLng(p[0].toDouble(), p[1].toDouble())).toList();
}
