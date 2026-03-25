import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'provider_details.dart';

class FindServices extends StatefulWidget {
  const FindServices({super.key});

  @override
  State<FindServices> createState() => _FindServicesState();
}

class _FindServicesState extends State<FindServices> {
  String selectedType = 'cleaner';

  double? userLatitude;
  double? userLongitude;
  bool loadingLocation = true;

  final List<Map<String, String>> categories = const [
    {'key': 'cleaner', 'label': 'Cleaner'},
    {'key': 'plumber', 'label': 'Plumber'},
    {'key': 'electrician', 'label': 'Electrician'},
    {'key': 'carpenter', 'label': 'Carpenter'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => loadingLocation = false);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => loadingLocation = false);
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        userLatitude = position.latitude;
        userLongitude = position.longitude;
        loadingLocation = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loadingLocation = false);
      }
    }
  }

  String _priceText(dynamic value) {
    if (value == null) return 'Price not set';

    if (value is int) return 'Rs $value/hour';
    if (value is double) {
      return value % 1 == 0
          ? 'Rs ${value.toInt()}/hour'
          : 'Rs ${value.toStringAsFixed(2)}/hour';
    }

    final parsed = double.tryParse(value.toString());
    if (parsed == null) return 'Price not set';

    return parsed % 1 == 0
        ? 'Rs ${parsed.toInt()}/hour'
        : 'Rs ${parsed.toStringAsFixed(2)}/hour';
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _daysText(List<String> days) {
    if (days.isEmpty) return 'Not set';
    return days.join(', ');
  }

  void _openProviderDetails(String providerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderDetailsPage(providerId: providerId),
      ),
    );
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  double? _distanceKm({
    required double? fromLat,
    required double? fromLng,
    required double? toLat,
    required double? toLng,
  }) {
    if (fromLat == null || fromLng == null || toLat == null || toLng == null) {
      return null;
    }

    const earthRadiusKm = 6371.0;

    final dLat = _degToRad(toLat - fromLat);
    final dLng = _degToRad(toLng - fromLng);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
            math.cos(_degToRad(fromLat)) *
                math.cos(_degToRad(toLat)) *
                math.sin(dLng / 2) *
                math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double deg) {
    return deg * (math.pi / 180);
  }

  String _distanceText(double? distanceKm) {
    if (distanceKm == null) return 'Distance unavailable';

    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).round();
      return '$meters m away';
    }

    return '${distanceKm.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Services'),
      ),
      body: Column(
        children: [
          if (loadingLocation)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Getting your location...'),
            ),
          if (!loadingLocation)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Showing currently available providers',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey,
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = categories[index];
                final isSelected = selectedType == item['key'];

                return ChoiceChip(
                  label: Text(item['label']!),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => selectedType = item['key']!);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'provider')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }

                final docs = (snap.data?.docs ?? []).where((doc) {
                  final data = doc.data();

                  final approved = (data['approved'] ?? false) == true;
                  final blocked = (data['blocked'] ?? false) == true;
                  final setupComplete = (data['setupComplete'] ?? false) == true;
                  final isAvailable = (data['isAvailable'] ?? true) == true;
                  final serviceType =
                  (data['serviceType'] ?? '').toString().toLowerCase();

                  return approved &&
                      !blocked &&
                      setupComplete &&
                      isAvailable &&
                      serviceType == selectedType;
                }).toList()
                  ..sort((a, b) {
                    final aData = a.data();
                    final bData = b.data();

                    final aDistance = _distanceKm(
                      fromLat: userLatitude,
                      fromLng: userLongitude,
                      toLat: _toDouble(aData['latitude']),
                      toLng: _toDouble(aData['longitude']),
                    );

                    final bDistance = _distanceKm(
                      fromLat: userLatitude,
                      fromLng: userLongitude,
                      toLat: _toDouble(bData['latitude']),
                      toLng: _toDouble(bData['longitude']),
                    );

                    if (aDistance != null && bDistance != null) {
                      return aDistance.compareTo(bDistance);
                    }

                    if (aDistance != null && bDistance == null) return -1;
                    if (aDistance == null && bDistance != null) return 1;

                    final aName = (aData['name'] ?? '').toString().toLowerCase();
                    final bName = (bData['name'] ?? '').toString().toLowerCase();
                    return aName.compareTo(bName);
                  });

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        loadingLocation
                            ? 'No available providers found for this service'
                            : 'No available providers found for this service right now',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    final name = data['name']?.toString() ?? 'Unknown';
                    final description =
                        data['serviceDescription']?.toString() ??
                            'No description available';
                    final price = data['pricePerHour'];
                    final phone = data['phone']?.toString() ?? 'No phone';
                    final availableDays = ((data['availableDays'] ?? []) as List)
                        .map((e) => e.toString())
                        .toList();
                    final startHour = data['startHour']?.toString() ?? 'Not set';
                    final endHour = data['endHour']?.toString() ?? 'Not set';

                    final providerLatitude = _toDouble(data['latitude']);
                    final providerLongitude = _toDouble(data['longitude']);
                    final distanceKm = _distanceKm(
                      fromLat: userLatitude,
                      fromLng: userLongitude,
                      toLat: providerLatitude,
                      toLng: providerLongitude,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openProviderDetails(doc.id),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Available Now',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _capitalize(selectedType),
                                style: const TextStyle(
                                  color: Colors.blueGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(description),
                              const SizedBox(height: 8),
                              Text(
                                _priceText(price),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Phone: $phone'),
                              const SizedBox(height: 4),
                              Text('Days: ${_daysText(availableDays)}'),
                              const SizedBox(height: 4),
                              Text('Hours: $startHour - $endHour'),
                              const SizedBox(height: 4),
                              Text('Distance: ${_distanceText(distanceKm)}'),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton(
                                  onPressed: () => _openProviderDetails(doc.id),
                                  child: const Text('View Details'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}