import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../services/location_service.dart';
import '../../services/request_service.dart';
import '../../shared/screen/select_location_map.dart';
import 'activity.dart';

class ProviderDetailsPage extends StatefulWidget {
  final String providerId;

  const ProviderDetailsPage({
    super.key,
    required this.providerId,
  });

  @override
  State<ProviderDetailsPage> createState() => _ProviderDetailsPageState();
}

class _ProviderDetailsPageState extends State<ProviderDetailsPage> {
  final TextEditingController _problemController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final LocationService _locationService = LocationService();
  final RequestService _requestService = RequestService();

  bool bookingLoading = false;

  double? serviceLatitude;
  double? serviceLongitude;

  static const Color primary = Color(0xff326178);
  static const Color pageBg = Color(0xffffffff);
  static const Color borderColor = Color(0xffe3dce8);
  static const Color titleColor = Color(0xff284a79);

  @override
  void dispose() {
    _problemController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _priceText(dynamic value) {
    if (value == null) return 'Price not set';

    if (value is int) return 'NPR $value/hour';
    if (value is double) {
      return value % 1 == 0
          ? 'NPR ${value.toInt()}/hour'
          : 'NPR ${value.toStringAsFixed(2)}/hour';
    }

    final parsed = double.tryParse(value.toString());
    if (parsed == null) return 'Price not set';

    return parsed % 1 == 0
        ? 'NPR ${parsed.toInt()}/hour'
        : 'NPR ${parsed.toStringAsFixed(2)}/hour';
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _daysText(List<String> days) {
    if (days.isEmpty) return 'Not set';
    return days.join(', ');
  }

  String _coordinateText(double? value) {
    if (value == null) return 'Not selected';
    return _locationService.formatCoordinate(value);
  }

  String _errorText(Object error) {
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    return text;
  }

  Future<void> _pickServiceLocationOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SelectLocationMapPage(),
      ),
    );

    if (!mounted || result == null) return;

    final latValue = result['latitude'];
    final lngValue = result['longitude'];
    final addressValue = result['locationAddress'];

    final pickedLat =
    latValue is num ? latValue.toDouble() : double.tryParse('$latValue');

    final pickedLng =
    lngValue is num ? lngValue.toDouble() : double.tryParse('$lngValue');

    if (pickedLat == null || pickedLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid location selected')),
      );
      return;
    }

    String resolvedAddress = addressValue?.toString().trim() ?? '';

    if (resolvedAddress.isEmpty) {
      try {
        resolvedAddress = await _locationService.reverseGeocode(
          LatLng(pickedLat, pickedLng),
        );
      } catch (_) {
        resolvedAddress = '';
      }
    }

    if (resolvedAddress.isEmpty) {
      resolvedAddress = 'Selected on map';
    }

    if (!mounted) return;

    setState(() {
      serviceLatitude = pickedLat;
      serviceLongitude = pickedLng;
      _addressController.text = resolvedAddress;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Service location selected')),
    );
  }

  Future<void> _submitBooking(Map<String, dynamic> providerData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final problem = _problemController.text.trim();
    final address = _addressController.text.trim();

    if (problem.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the problem description')),
      );
      return;
    }

    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick the service location on map')),
      );
      return;
    }

    if (serviceLatitude == null || serviceLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick the service location on map')),
      );
      return;
    }

    final providerId = widget.providerId;

    try {
      setState(() => bookingLoading = true);

      await _requestService.createServiceRequest(
        userId: user.uid,
        providerId: providerId,
        providerData: providerData,
        problemDescription: problem,
        serviceAddress: address,
        serviceLatitude: serviceLatitude!,
        serviceLongitude: serviceLongitude!,
      );

      if (!mounted) return;

      _problemController.clear();
      _addressController.clear();

      setState(() {
        serviceLatitude = null;
        serviceLongitude = null;
        bookingLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Service request sent successfully')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Activity()),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => bookingLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: ${_errorText(e)}')),
      );
    }
  }

  Widget _buildTopHeader(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: topInset + 16,
        left: 18,
        right: 18,
        bottom: 18,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff326178), Color(0xffdff1fc)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Provider Details',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(String title, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
          ),
          const SizedBox(height: 6),
          Text(value),
        ],
      ),
    );
  }

  Widget _buildStarRow(double averageRating) {
    final rounded = averageRating.round();

    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rounded ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 22,
        );
      }),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primary, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.providerId)
            .snapshots(),
        builder: (context, providerSnap) {
          if (providerSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (providerSnap.hasError) {
            return Center(child: Text('Error: ${providerSnap.error}'));
          }

          if (!providerSnap.hasData ||
              !providerSnap.data!.exists ||
              providerSnap.data!.data() == null) {
            return const Center(child: Text('Provider not found'));
          }

          final data = providerSnap.data!.data()!;
          final name = data['name']?.toString() ?? 'Unknown';
          final serviceType = data['serviceType']?.toString() ?? 'Not set';
          final description =
              data['serviceDescription']?.toString() ?? 'No description';
          final phone = data['phone']?.toString() ?? 'No phone';

          final currentLocationAddress =
              data['currentLocationAddress']?.toString().trim() ?? '';
          final locationAddress =
              data['locationAddress']?.toString().trim() ?? '';
          final profileAddress =
              data['address']?.toString().trim() ?? '';

          final address = currentLocationAddress.isNotEmpty
              ? currentLocationAddress
              : (locationAddress.isNotEmpty
              ? locationAddress
              : (profileAddress.isNotEmpty ? profileAddress : 'No address'));

          final locationType = currentLocationAddress.isNotEmpty
              ? 'Last known device location'
              : 'Work location';

          final price = data['pricePerHour'];

          final isAvailable = (data['isAvailable'] ?? true) == true;
          final availableDays = ((data['availableDays'] ?? []) as List)
              .map((e) => e.toString())
              .toList();
          final startHour = data['startHour']?.toString() ?? 'Not set';
          final endHour = data['endHour']?.toString() ?? 'Not set';

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('reviews')
                .where('providerId', isEqualTo: widget.providerId)
                .snapshots(),
            builder: (context, reviewSnap) {
              final reviewDocs = reviewSnap.data?.docs ?? [];

              double averageRating = 0;
              if (reviewDocs.isNotEmpty) {
                double total = 0;
                for (final doc in reviewDocs) {
                  final value = doc.data()['rating'];
                  if (value is int) {
                    total += value.toDouble();
                  } else if (value is double) {
                    total += value;
                  } else {
                    total += double.tryParse(value.toString()) ?? 0;
                  }
                }
                averageRating = total / reviewDocs.length;
              }

              final recentReviews = [...reviewDocs]
                ..sort((a, b) {
                  final aTime = a.data()['createdAt'];
                  final bTime = b.data()['createdAt'];
                  if (aTime is Timestamp && bTime is Timestamp) {
                    return bTime.compareTo(aTime);
                  }
                  return 0;
                });

              return Column(
                children: [
                  _buildTopHeader(context),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                _buildStarRow(averageRating),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    reviewDocs.isEmpty
                                        ? 'No ratings yet'
                                        : '${averageRating.toStringAsFixed(1)} / 5  (${reviewDocs.length} reviews)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? Colors.green.withValues(alpha: 0.10)
                                  : Colors.red.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isAvailable
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color: isAvailable ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isAvailable
                                      ? 'Currently Available'
                                      : 'Currently Unavailable',
                                  style: TextStyle(
                                    color:
                                    isAvailable ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _infoCard('Service Type', _capitalize(serviceType)),
                          _infoCard('Description', description),
                          _infoCard('Price Per Hour', _priceText(price)),
                          _infoCard('Phone', phone),
                          _infoCard('Address', address),
                          _infoCard('Location Type', locationType),
                          _infoCard('Available Days', _daysText(availableDays)),
                          _infoCard('Working Hours', '$startHour - $endHour'),
                          const SizedBox(height: 18),
                          const Text(
                            'Request This Service',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _problemController,
                            maxLines: 4,
                            decoration: _fieldDecoration(
                              label: 'Problem Description',
                              hint: 'Describe the service you need',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _addressController,
                            maxLines: 2,
                            readOnly: true,
                            decoration: _fieldDecoration(
                              label: 'Service Address',
                              hint: 'This will auto-fill from map',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on, color: primary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Selected Service Location\nLat: ${_coordinateText(serviceLatitude)}\nLng: ${_coordinateText(serviceLongitude)}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _pickServiceLocationOnMap,
                              icon: const Icon(Icons.map),
                              label: Text(
                                serviceLatitude != null &&
                                    serviceLongitude != null
                                    ? 'Update Service Location on Map'
                                    : 'Pick Service Location on Map',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: bookingLoading || !isAvailable
                                  ? null
                                  : () => _submitBooking(data),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isAvailable
                                    ? const Color(0xff7c5ac7)
                                    : Colors.grey,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: bookingLoading
                                  ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : Text(
                                isAvailable
                                    ? 'Confirm Booking'
                                    : 'Provider Unavailable',
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Recent Reviews',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (reviewDocs.isEmpty)
                            const Text('No reviews yet')
                          else
                            ...recentReviews.take(5).map((doc) {
                              final review = doc.data();
                              final userName =
                                  review['userName']?.toString() ?? 'User';
                              final reviewText =
                                  review['reviewText']?.toString() ?? '';
                              final ratingValue = review['rating'];
                              final reviewRating = ratingValue is int
                                  ? ratingValue
                                  : int.tryParse(ratingValue.toString()) ?? 0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: List.generate(5, (index) {
                                        return Icon(
                                          index < reviewRating
                                              ? Icons.star
                                              : Icons.star_border,
                                          color: Colors.amber,
                                          size: 18,
                                        );
                                      }),
                                    ),
                                    if (reviewText.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(reviewText),
                                    ],
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}