import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class SelectLocationMapPage extends StatefulWidget {
  const SelectLocationMapPage({super.key});

  @override
  State<SelectLocationMapPage> createState() => _SelectLocationMapPageState();
}

class _SelectLocationMapPageState extends State<SelectLocationMapPage> {
  GoogleMapController? _mapController;
  bool _loading = true;
  String? _errorMessage;

  LatLng? _currentLatLng;
  LatLng? _selectedLatLng;

  final CameraPosition _fallbackCamera = const CameraPosition(
    target: LatLng(27.7172, 85.3240), // Kathmandu fallback
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<bool> _handlePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Please enable location services.');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permission is required to use the map.');
      return false;
    }

    return true;
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final granted = await _handlePermission();
      if (!granted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Location permission not granted.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final current = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {
        _currentLatLng = current;
        _selectedLatLng = current;
        _loading = false;
      });

      await Future.delayed(const Duration(milliseconds: 300));

      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: current, zoom: 16),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Failed to load map: $e';
      });
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};

    if (_currentLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: _currentLatLng!,
          infoWindow: const InfoWindow(title: 'Current Location'),
        ),
      );
    }

    if (_selectedLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('selected'),
          position: _selectedLatLng!,
          infoWindow: const InfoWindow(title: 'Selected Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueBlue,
          ),
        ),
      );
    }

    return markers;
  }

  Future<void> _goToCurrentLocation() async {
    if (_currentLatLng == null) return;

    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLatLng!, zoom: 16),
      ),
    );
  }

  void _confirmLocation() {
    if (_selectedLatLng == null) {
      _showSnackBar('Please select a location first.');
      return;
    }

    Navigator.pop(context, {
      'latitude': _selectedLatLng!.latitude,
      'longitude': _selectedLatLng!.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _fallbackCamera,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers(),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: (latLng) {
              setState(() {
                _selectedLatLng = latLng;
              });
            },
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