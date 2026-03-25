import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static const LatLng fallbackLatLng = LatLng(27.7172, 85.3240); // Kathmandu

  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<LatLng?> getCurrentLatLng({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    final granted = await ensurePermission();
    if (!granted) return null;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: accuracy),
    );

    return LatLng(position.latitude, position.longitude);
  }

  Future<LatLng?> searchAddress(String query) async {
    final text = query.trim();
    if (text.isEmpty) return null;

    final results = await locationFromAddress(text);
    if (results.isEmpty) return null;

    final first = results.first;
    return LatLng(first.latitude, first.longitude);
  }

  Future<String> reverseGeocode(LatLng point) async {
    final placemarks = await placemarkFromCoordinates(
      point.latitude,
      point.longitude,
    );

    if (placemarks.isEmpty) return '';

    final p = placemarks.first;

    final parts = [
      p.street,
      p.subLocality,
      p.locality,
      p.administrativeArea,
      p.country,
    ]
        .where((e) => e != null && e.trim().isNotEmpty)
        .map((e) => e!.trim())
        .toList();

    if (parts.isEmpty) return '';
    return parts.join(', ');
  }

  String formatCoordinate(double value) {
    return value.toStringAsFixed(6);
  }
}