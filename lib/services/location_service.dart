import 'dart:math' as math;

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

  double calculateDistanceKm({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    const earthRadiusKm = 6371.0;

    final dLat = _degToRad(endLat - startLat);
    final dLng = _degToRad(endLng - startLng);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(_degToRad(startLat)) *
                math.cos(_degToRad(endLat)) *
                math.sin(dLng / 2) *
                math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double calculateDistanceKmBetweenPoints(LatLng a, LatLng b) {
    return calculateDistanceKm(
      startLat: a.latitude,
      startLng: a.longitude,
      endLat: b.latitude,
      endLng: b.longitude,
    );
  }

  String formatDistanceKm(double distanceKm) {
    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).round();
      return '$meters m away';
    }
    return '${distanceKm.toStringAsFixed(1)} km away';
  }

  bool isWithinRadiusKm({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required double radiusKm,
  }) {
    final distance = calculateDistanceKm(
      startLat: startLat,
      startLng: startLng,
      endLat: endLat,
      endLng: endLng,
    );

    return distance <= radiusKm;
  }

  String formatCoordinate(double value) {
    return value.toStringAsFixed(6);
  }

  double _degToRad(double degree) {
    return degree * (math.pi / 180.0);
  }
}