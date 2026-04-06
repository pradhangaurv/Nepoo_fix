import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../auth/login_screen.dart';
import '../../services/location_service.dart';
import '../../shared/screen/select_location_map.dart';
import 'provider_setup.dart';

class ProviderSettings extends StatefulWidget {
  const ProviderSettings({super.key});

  @override
  State<ProviderSettings> createState() => _ProviderSettingsState();
}

class _ProviderSettingsState extends State<ProviderSettings> {
  final LocationService _locationService = LocationService();

  bool loading = true;
  bool saving = false;

  bool isAvailable = true;
  List<String> selectedDays = [];
  String startHour = '09:00 AM';
  String endHour = '06:00 PM';

  String providerName = '';
  String serviceType = '';
  String serviceDescription = '';
  String locationAddress = '';
  dynamic pricePerHour;
  double? latitude;
  double? longitude;

  static const Color providerDark = Color(0xff244657);
  static const Color providerLight = Color(0xff7fa7bd);
  static const Color pageBg = Color(0xfff4eff5);
  static const Color borderColor = Color(0xffe3dce8);

  final List<String> allDays = const [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => loading = false);
      }
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data() ?? <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        providerName = data['name']?.toString() ?? '';
        isAvailable = (data['isAvailable'] ?? true) == true;
        selectedDays = ((data['availableDays'] ?? []) as List)
            .map((e) => e.toString())
            .toList();
        startHour = data['startHour']?.toString() ?? '09:00 AM';
        endHour = data['endHour']?.toString() ?? '06:00 PM';

        serviceType = data['serviceType']?.toString() ?? '';
        serviceDescription = data['serviceDescription']?.toString() ?? '';
        locationAddress = data['locationAddress']?.toString() ?? '';
        pricePerHour = data['pricePerHour'];

        final latValue = data['latitude'];
        final lngValue = data['longitude'];

        latitude = latValue is num
            ? latValue.toDouble()
            : double.tryParse('$latValue');
        longitude = lngValue is num
            ? lngValue.toDouble()
            : double.tryParse('$lngValue');

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load settings: $e')),
      );
    }
  }

  String _priceText(dynamic value) {
    if (value == null) return 'Not set';

    if (value is int) return 'Rs $value/hour';
    if (value is double) {
      return value % 1 == 0
          ? 'Rs ${value.toInt()}/hour'
          : 'Rs ${value.toStringAsFixed(2)}/hour';
    }

    final parsed = double.tryParse(value.toString());
    if (parsed == null) return 'Not set';

    return parsed % 1 == 0
        ? 'Rs ${parsed.toInt()}/hour'
        : 'Rs ${parsed.toStringAsFixed(2)}/hour';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (!mounted || picked == null) return;

    setState(() {
      if (isStart) {
        startHour = _formatTime(picked);
      } else {
        endHour = _formatTime(picked);
      }
    });
  }

  Future<void> _pickWorkLocationOnMap() async {
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

    final pickedLat = latValue is num
        ? latValue.toDouble()
        : double.tryParse('$latValue');

    final pickedLng = lngValue is num
        ? lngValue.toDouble()
        : double.tryParse('$lngValue');

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
      latitude = pickedLat;
      longitude = pickedLng;
      locationAddress = resolvedAddress;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Work location selected')),
    );
  }

  Future<void> _saveAvailability() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one available day')),
      );
      return;
    }

    try {
      setState(() => saving = true);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'isAvailable': isAvailable,
        'availableDays': selectedDays,
        'startHour': startHour,
        'endHour': endHour,
        'locationAddress': locationAddress,
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save settings: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  Future<void> _openEditOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Profile'),
                subtitle: const Text(
                  'Update name, service, description, and rate',
                ),
                onTap: () async {
                  Navigator.pop(context);

                  await Navigator.push(
                    this.context,
                    MaterialPageRoute(
                      builder: (_) => const ProviderSetupScreen(),
                    ),
                  );

                  if (!mounted) return;
                  await _loadAvailability();
                },
              ),
              ListTile(
                leading: const Icon(Icons.map),
                title: const Text('Edit Work Location'),
                subtitle: const Text('Pick your work location on map'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickWorkLocationOnMap();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MyLogin()),
          (_) => false,
    );
  }

  Widget _dayChip(String day) {
    final selected = selectedDays.contains(day);

    return FilterChip(
      label: Text(day),
      selected: selected,
      onSelected: (value) {
        setState(() {
          if (value) {
            if (!selectedDays.contains(day)) {
              selectedDays.add(day);
            }
          } else {
            selectedDays.remove(day);
          }
        });
      },
    );
  }

  Widget _timeTile({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        title: Text(title),
        subtitle: Text(value),
        trailing: const Icon(Icons.access_time),
        onTap: onTap,
      ),
    );
  }

  Widget _summaryTile(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        title: Text(title),
        subtitle: Text(value),
      ),
    );
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
          colors: [providerDark, providerLight],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Provider Settings",
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: "Edit",
            onPressed: _openEditOptions,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        backgroundColor: pageBg,
        body: Column(
          children: [
            _buildTopHeader(context),
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: pageBg,
      body: Column(
        children: [
          _buildTopHeader(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Provider Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _summaryTile(
                    'Provider Name',
                    providerName.isEmpty ? 'Not set' : providerName,
                  ),
                  _summaryTile(
                    'Service',
                    serviceType.isEmpty ? 'Not set' : serviceType,
                  ),
                  _summaryTile(
                    'Description',
                    serviceDescription.isEmpty ? 'Not set' : serviceDescription,
                  ),
                  _summaryTile(
                    'Rate',
                    _priceText(pricePerHour),
                  ),
                  _summaryTile(
                    'Work Location',
                    locationAddress.isEmpty ? 'Not set' : locationAddress,
                  ),
                  const SizedBox(height: 8),
                  if (locationAddress.isNotEmpty)
                    Text(
                      'Work location is set.',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Text(
                      'Work location is not set yet.',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: SwitchListTile(
                      value: isAvailable,
                      title: const Text(
                        'Currently Available',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isAvailable
                            ? 'Users can request your service'
                            : 'Users cannot book you right now',
                      ),
                      onChanged: (value) {
                        setState(() => isAvailable = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Available Days',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allDays.map(_dayChip).toList(),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Working Hours',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _timeTile(
                    title: 'Start Time',
                    value: startHour,
                    onTap: () => _pickTime(isStart: true),
                  ),
                  _timeTile(
                    title: 'End Time',
                    value: endHour,
                    onTap: () => _pickTime(isStart: false),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: saving ? null : _saveAvailability,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: providerDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: saving
                          ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text('Save Settings'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout),
                      label: const Text("Logout"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}