import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class SelectLocationMapPage extends StatefulWidget {
  const SelectLocationMapPage({super.key});

  @override
  State<SelectLocationMapPage> createState() => _SelectLocationMapPageState();
}

class _SelectLocationMapPageState extends State<SelectLocationMapPage> {
  final MapController _mapController = MapController();

  bool _loading = true;
  String? _errorMessage;

  LatLng? _currentLatLng;
  LatLng? _selectedLatLng;

  static const LatLng _fallbackLatLng = LatLng(27.7172, 85.3240); // Kathmandu

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<bool> _handlePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable location services.')),
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is required.')),
      );
      return false;
    }

    return true;
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final granted = await _handlePermission();

      if (!mounted) return;

      if (!granted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Location permission not granted.';
          _selectedLatLng = _fallbackLatLng;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      final current = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLatLng = current;
        _selectedLatLng = current;
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(current, 16);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'Failed to load location.';
        _selectedLatLng = _fallbackLatLng;
      });
    }
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      final current = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLatLng = current;
        _selectedLatLng = current;
      });

      _mapController.move(current, 16);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get current location.')),
      );
    }
  }

  void _confirmLocation() {
    if (_selectedLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location first.')),
      );
      return;
    }

    Navigator.pop(context, {
      'latitude': _selectedLatLng!.latitude,
      'longitude': _selectedLatLng!.longitude,
    });
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    if (_currentLatLng != null) {
      markers.add(
        Marker(
          point: _currentLatLng!,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.my_location,
            color: Colors.blue,
            size: 32,
          ),
        ),
      );
    }

    if (_selectedLatLng != null) {
      markers.add(
        Marker(
          point: _selectedLatLng!,
          width: 44,
          height: 44,
          child: const Icon(
            Icons.location_pin,
            color: Colors.red,
            size: 40,
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final center = _selectedLatLng ?? _fallbackLatLng;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedLatLng = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.nepoo_fix',
              ),
              MarkerLayer(
                markers: _buildMarkers(),
              ),
              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
                showFlutterMapAttribution: false,
              ),
            ],
          ),
          if (_errorMessage != null)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Material(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_errorMessage!),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 90,
            child: FloatingActionButton(
              onPressed: _goToCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: ElevatedButton(
              onPressed: _confirmLocation,
              child: const Text('Use This Location'),
            ),
          ),
        ],
      ),
    );
  }
}