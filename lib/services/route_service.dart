import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteService {
  Future<List<LatLng>> getDrivingRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = (data['routes'] as List?) ?? [];

    if (routes.isEmpty) {
      return [];
    }

    final geometry = routes.first['geometry'] as Map<String, dynamic>? ?? {};
    final coordinates = (geometry['coordinates'] as List?) ?? [];

    return coordinates
        .whereType<List>()
        .map((c) {
      if (c.length < 2) return null;

      final lng = (c[0] as num).toDouble();
      final lat = (c[1] as num).toDouble();

      return LatLng(lat, lng);
    })
        .whereType<LatLng>()
        .toList();
  }
}