import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/location_service.dart';

class SelectLocationMapPage extends StatefulWidget {
  const SelectLocationMapPage({super.key});

  @override
  State<SelectLocationMapPage> createState() => _SelectLocationMapPageState();
}

class _SelectLocationMapPageState extends State<SelectLocationMapPage> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final LocationService _locationService = LocationService();

  bool _loading = true;
  bool _searching = false;
  bool _resolvingAddress = false;

  String? _errorMessage;
  String _selectedAddress = '';

  LatLng? _currentLatLng;
  LatLng? _selectedLatLng;

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final current = await _locationService.getCurrentLatLng();

      if (!mounted) return;

      if (current == null) {
        setState(() {
          _loading = false;
          _errorMessage = 'Location permission not granted.';
          _selectedLatLng = LocationService.fallbackLatLng;
        });

        await _updateSelectedAddress(LocationService.fallbackLatLng);
        return;
      }

      setState(() {
        _currentLatLng = current;
        _selectedLatLng = current;
        _loading = false;
        _errorMessage = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(current, 16);
      });

      await _updateSelectedAddress(current);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'Failed to load location.';
        _selectedLatLng = LocationService.fallbackLatLng;
      });

      await _updateSelectedAddress(LocationService.fallbackLatLng);
    }
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final current = await _locationService.getCurrentLatLng();

      if (!mounted) return;

      if (current == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get current location.')),
        );
        return;
      }

      setState(() {
        _currentLatLng = current;
        _selectedLatLng = current;
        _errorMessage = null;
      });

      _mapController.move(current, 16);
      await _updateSelectedAddress(current);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not get current location.')),
      );
    }
  }

  Future<void> _searchLocation() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a place or address.')),
      );
      return;
    }

    try {
      setState(() {
        _searching = true;
        _errorMessage = null;
      });

      final point = await _locationService.searchAddress(query);

      if (!mounted) return;

      if (point == null) {
        setState(() {
          _searching = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No location found for that search.')),
        );
        return;
      }

      setState(() {
        _selectedLatLng = point;
        _searching = false;
      });

      _mapController.move(point, 16);
      await _updateSelectedAddress(point);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _searching = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search failed. Try another address.')),
      );
    }
  }

  Future<void> _updateSelectedAddress(LatLng point) async {
    try {
      if (!mounted) return;

      setState(() {
        _resolvingAddress = true;
      });

      final address = await _locationService.reverseGeocode(point);

      if (!mounted) return;

      setState(() {
        _selectedAddress = address;
        _resolvingAddress = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _selectedAddress = '';
        _resolvingAddress = false;
      });
    }
  }

  Future<void> _onMapTap(LatLng point) async {
    setState(() {
      _selectedLatLng = point;
      _errorMessage = null;
    });

    await _updateSelectedAddress(point);
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
      'locationAddress': _selectedAddress,
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

  String _coordinateText(double value) {
    return _locationService.formatCoordinate(value);
  }

  @override
  Widget build(BuildContext context) {
    final center = _selectedLatLng ?? LocationService.fallbackLatLng;

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
              onTap: (_, point) => _onMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchLocation(),
                    decoration: InputDecoration(
                      hintText: 'Search place or address',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searching
                          ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      )
                          : IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _searchLocation,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_errorMessage!)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 84,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _selectedLatLng == null
                    ? const Text('Tap on the map to select a location.')
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Selected Location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Latitude: ${_coordinateText(_selectedLatLng!.latitude)}',
                    ),
                    Text(
                      'Longitude: ${_coordinateText(_selectedLatLng!.longitude)}',
                    ),
                    const SizedBox(height: 6),
                    if (_resolvingAddress)
                      const Text('Resolving address...')
                    else
                      Text(
                        _selectedAddress.isEmpty
                            ? 'Address not available'
                            : _selectedAddress,
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 170,
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