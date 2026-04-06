import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/location_service.dart';
import 'provider_details.dart';

class FindServices extends StatefulWidget {
  final String? selectedType;

  const FindServices({super.key, this.selectedType});

  @override
  State<FindServices> createState() => _FindServicesState();
}

class _FindServicesState extends State<FindServices> {
  final LocationService _locationService = LocationService();

  late String selectedType;
  bool loadingLocation = true;
  bool locationAvailable = false;

  static const Color primary = Color(0xff326178);
  static const Color pageBg = Color(0xfff4eff5);
  static const Color titleColor = Color(0xff284a79);
  static const Color borderColor = Color(0xffe3dce8);
  static const Color chipSelectedBg = Color(0xffddd0f1);
  static const Color chipSelectedText = Color(0xff4a3a73);

  final List<Map<String, String>> categories = const [
    {'key': 'cleaner', 'label': 'Cleaner'},
    {'key': 'plumber', 'label': 'Plumber'},
    {'key': 'electrician', 'label': 'Electrician'},
    {'key': 'carpenter', 'label': 'Carpenter'},
  ];

  @override
  void initState() {
    super.initState();
    selectedType = widget.selectedType?.toLowerCase() ?? 'cleaner';
    _loadCurrentLocation();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final current = await _locationService.getCurrentLatLng();
      if (!mounted) return;
      setState(() {
        loadingLocation = false;
        locationAvailable = current != null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingLocation = false;
        locationAvailable = false;
      });
    }
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

  void _openProviderDetails(String providerId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderDetailsPage(providerId: providerId),
      ),
    );
  }

  String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

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
              'Find Services',
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

  Widget _buildCategoryChip(String key, String label) {
    final isSelected = selectedType == key;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() => selectedType = key);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? chipSelectedBg : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? chipSelectedBg : borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? chipSelectedText : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _providerCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
                      data['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Available Now',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _capitalize(selectedType),
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _priceText(data['pricePerHour']),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 140,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => _openProviderDetails(doc.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBg,
      body: Column(
        children: [
          _buildTopHeader(context),
          if (loadingLocation)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Checking provider availability...',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
            ),
          if (!loadingLocation)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  locationAvailable
                      ? 'Showing currently available providers'
                      : 'Showing available providers',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = categories[index];
                return _buildCategoryChip(item['key']!, item['label']!);
              },
            ),
          ),
          const SizedBox(height: 12),
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
                  final serviceTypeData =
                  (data['serviceType'] ?? '').toString().toLowerCase();

                  return approved &&
                      !blocked &&
                      setupComplete &&
                      isAvailable &&
                      serviceTypeData == selectedType;
                }).toList()
                  ..sort((a, b) {
                    final aName = (a.data()['name'] ?? '').toString().toLowerCase();
                    final bName = (b.data()['name'] ?? '').toString().toLowerCase();
                    return aName.compareTo(bName);
                  });

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No available providers found for this service right now',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    return _providerCard(docs[index]);
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