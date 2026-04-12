import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../services/location_service.dart';
import 'provider_details.dart';

class FindServices extends StatefulWidget {
  final String? selectedType;
  final bool showBackButton;

  const FindServices({
    super.key,
    this.selectedType,
    this.showBackButton = false,
  });

  @override
  State<FindServices> createState() => _FindServicesState();
}

class _FindServicesState extends State<FindServices> {
  final LocationService _locationService = LocationService();
  final TextEditingController _searchController = TextEditingController();

  late String selectedType;

  bool loadingLocation = true;
  bool locationAvailable = false;
  LatLng? _userLatLng;

  String _searchText = '';
  String _sortBy = 'nearest'; // nearest | name
  String _radiusFilter = 'all'; // all | 5 | 10 | 20

  static const Color primary = Color(0xff326178);
  static const Color pageBg = Color(0xffffffff);
  static const Color titleColor = Color(0xff284a79);
  static const Color borderColor = Color(0xffe3dce8);
  static const Color chipSelectedBg = Color(0xffb6d1e3);
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentLocation() async {
    try {
      final current = await _locationService.getCurrentLatLng();
      if (!mounted) return;

      setState(() {
        _userLatLng = current;
        loadingLocation = false;
        locationAvailable = current != null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _userLatLng = null;
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

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  String _locationLabel(Map<String, dynamic> data) {
    final currentAddress =
        data['currentLocationAddress']?.toString().trim() ?? '';
    final workAddress = data['locationAddress']?.toString().trim() ?? '';
    final profileAddress = data['address']?.toString().trim() ?? '';

    if (currentAddress.isNotEmpty) return currentAddress;
    if (workAddress.isNotEmpty) return workAddress;
    if (profileAddress.isNotEmpty) return profileAddress;

    return 'Location not available';
  }

  LatLng? _providerLatLng(Map<String, dynamic> data) {
    final currentLat = _toDouble(data['currentLatitude']);
    final currentLng = _toDouble(data['currentLongitude']);

    if (currentLat != null && currentLng != null) {
      return LatLng(currentLat, currentLng);
    }

    final workLat = _toDouble(data['latitude']);
    final workLng = _toDouble(data['longitude']);

    if (workLat != null && workLng != null) {
      return LatLng(workLat, workLng);
    }

    return null;
  }

  String _distanceText(Map<String, dynamic> data) {
    if (_userLatLng == null) return 'Distance unavailable';

    final providerPoint = _providerLatLng(data);
    if (providerPoint == null) return 'Distance unavailable';

    final km = _locationService.calculateDistanceKmBetweenPoints(
      _userLatLng!,
      providerPoint,
    );

    return _locationService.formatDistanceKm(km);
  }

  double? _distanceKm(Map<String, dynamic> data) {
    if (_userLatLng == null) return null;

    final providerPoint = _providerLatLng(data);
    if (providerPoint == null) return null;

    return _locationService.calculateDistanceKmBetweenPoints(
      _userLatLng!,
      providerPoint,
    );
  }

  bool _passesRadiusFilter(Map<String, dynamic> data) {
    if (_radiusFilter == 'all') return true;
    if (_userLatLng == null) return true;

    final providerPoint = _providerLatLng(data);
    if (providerPoint == null) return false;

    final radiusKm = double.tryParse(_radiusFilter);
    if (radiusKm == null) return true;

    return _locationService.isWithinRadiusKm(
      startLat: _userLatLng!.latitude,
      startLng: _userLatLng!.longitude,
      endLat: providerPoint.latitude,
      endLng: providerPoint.longitude,
      radiusKm: radiusKm,
    );
  }

  bool _passesSearch(Map<String, dynamic> data) {
    final search = _searchText.trim().toLowerCase();
    if (search.isEmpty) return true;

    final name = (data['name'] ?? '').toString().toLowerCase();
    final serviceType = (data['serviceType'] ?? '').toString().toLowerCase();
    final location = _locationLabel(data).toLowerCase();

    return name.contains(search) ||
        serviceType.contains(search) ||
        location.contains(search);
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
          if (widget.showBackButton) ...[
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
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
          IconButton(
            onPressed: _loadCurrentLocation,
            icon: const Icon(Icons.my_location, color: Colors.white),
            tooltip: 'Refresh location',
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

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchText = value);
        },
        decoration: InputDecoration(
          hintText: 'Search provider or location',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchText.isEmpty
              ? null
              : IconButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _searchText = '');
            },
            icon: const Icon(Icons.close),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _sortBy,
              decoration: InputDecoration(
                labelText: 'Sort by',
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primary, width: 1.4),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'nearest', child: Text('Nearest')),
                DropdownMenuItem(value: 'name', child: Text('A-Z')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _sortBy = value);
              },
              dropdownColor: Color(0xffd9ebf8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _radiusFilter,
              decoration: InputDecoration(
                labelText: 'Radius',
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primary, width: 1.4),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: '5', child: Text('Within 5 km')),
                DropdownMenuItem(value: '10', child: Text('Within 10 km')),
                DropdownMenuItem(value: '20', child: Text('Within 20 km')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _radiusFilter = value);
              },
              dropdownColor: Color(0xffd9ebf8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _providerCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final locationText = _locationLabel(data);
    final distanceText = _distanceText(data);

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
                      data['name']?.toString() ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 20,
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
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _capitalize(
                  (data['serviceType'] ?? selectedType).toString(),
                ),
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
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 18, color: primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      locationText,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.near_me, size: 17, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      distanceText,
                      style: const TextStyle(
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _prepareDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    final filtered = docs.where((doc) {
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
          serviceTypeData == selectedType &&
          _passesSearch(data) &&
          _passesRadiusFilter(data);
    }).toList();

    filtered.sort((a, b) {
      final aData = a.data();
      final bData = b.data();

      if (_sortBy == 'nearest') {
        final aDistance = _distanceKm(aData);
        final bDistance = _distanceKm(bData);

        if (aDistance != null && bDistance != null) {
          return aDistance.compareTo(bDistance);
        }
        if (aDistance != null) return -1;
        if (bDistance != null) return 1;
      }

      final aName = (aData['name'] ?? '').toString().toLowerCase();
      final bName = (bData['name'] ?? '').toString().toLowerCase();
      return aName.compareTo(bName);
    });

    return filtered;
  }

  Widget _buildLocationStatus() {
    if (loadingLocation) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Getting your current location...',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          locationAvailable
              ? 'Showing providers near your current location'
              : 'Location unavailable. Showing all matching providers',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.blueGrey,
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
          _buildLocationStatus(),
          const SizedBox(height: 6),
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
          _buildSearchBox(),
          _buildFilters(),
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

                final allDocs = snap.data?.docs ?? [];
                final docs = _prepareDocs(allDocs);

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.search_off,
                            size: 52,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No ${_capitalize(selectedType)} providers found',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Try another category, search, or radius filter.',
                            style: TextStyle(color: Colors.blueGrey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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