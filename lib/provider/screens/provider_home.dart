import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/chat_service.dart';
import '../../services/location_service.dart';
import '../../services/route_service.dart';
import '../../shared/screen/chat_page.dart';
import '../../shared/widgets/notification_bell.dart';

class ProviderHome extends StatefulWidget {
  const ProviderHome({super.key});

  @override
  State<ProviderHome> createState() => _ProviderHomeState();
}

class _ProviderHomeState extends State<ProviderHome> {
  final LocationService _locationService = LocationService();
  final RouteService _routeService = RouteService();
  final ChatService _chatService = ChatService();

  LatLng? _providerCurrentLatLng;
  bool _loadingLocation = true;
  String? _locationError;

  List<LatLng> _routePoints = [];
  bool _loadingRoute = false;
  String? _routeError;
  String? _routeKey;

  @override
  void initState() {
    super.initState();
    _loadProviderCurrentLocation();
  }

  Future<void> _loadProviderCurrentLocation() async {
    try {
      final current = await _locationService.getCurrentLatLng();

      if (!mounted) return;

      if (current == null) {
        setState(() {
          _loadingLocation = false;
          _locationError = 'Location permission not granted.';
        });
        return;
      }

      setState(() {
        _providerCurrentLatLng = current;
        _loadingLocation = false;
        _locationError = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingLocation = false;
        _locationError = 'Could not load your current location.';
      });
    }
  }

  Future<void> _loadRoute({
    required LatLng from,
    required LatLng to,
  }) async {
    final key =
        '${from.latitude},${from.longitude}->${to.latitude},${to.longitude}';

    if (_routeKey == key && (_routePoints.isNotEmpty || _loadingRoute)) return;

    try {
      if (mounted) {
        setState(() {
          _loadingRoute = true;
          _routeError = null;
          _routeKey = key;
        });
      }

      final points = await _routeService.getDrivingRoute(from: from, to: to);

      if (!mounted) return;

      setState(() {
        _routePoints = points;
        _loadingRoute = false;
        _routeError = points.isEmpty ? 'No route found.' : null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingRoute = false;
        _routeError = 'Failed to load route.';
        _routePoints = [];
      });
    }
  }

  String _priceText(dynamic value) {
    if (value == null) return "Not set";

    if (value is int) return "Rs $value / hour";
    if (value is double) {
      return value % 1 == 0
          ? "Rs ${value.toInt()} / hour"
          : "Rs ${value.toStringAsFixed(2)} / hour";
    }

    final parsed = double.tryParse(value.toString());
    if (parsed == null) return "Not set";

    return parsed % 1 == 0
        ? "Rs ${parsed.toInt()} / hour"
        : "Rs ${parsed.toStringAsFixed(2)} / hour";
  }

  String _daysText(List<String> days) {
    if (days.isEmpty) return "Not set";
    return days.join(', ');
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool _showMapForStatus(String status) {
    return status == 'accepted' || status == 'on_the_way';
  }

  bool _hasActiveJobWithoutMap(String status) {
    return status == 'arrived' || status == 'in_progress';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.blue;
      case 'on_the_way':
        return Colors.orange;
      case 'arrived':
        return Colors.teal;
      case 'in_progress':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'on_the_way':
        return 'On The Way';
      case 'in_progress':
        return 'In Progress';
      case 'arrived':
        return 'Arrived';
      case 'accepted':
        return 'Accepted';
      default:
        return 'No Active Job';
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text('$label$value'),
    );
  }

  void _openChatPage({
    required String requestId,
    required String customerId,
    required String providerId,
    required String customerName,
    required String customerPhone,
    required String status,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          requestId: requestId,
          customerId: customerId,
          providerId: providerId,
          currentUserId: currentUser.uid,
          currentUserRole: 'provider',
          otherUserName: customerName,
          otherUserPhone: customerPhone,
          requestStatus: status,
        ),
      ),
    );
  }

  Widget _buildUnreadBadge(int count) {
    return Positioned(
      right: -6,
      top: -6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
        child: Text(
          count > 99 ? '99+' : '$count',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildChatButton({
    required String requestId,
    required String customerId,
    required String providerId,
    required String customerName,
    required String customerPhone,
    required String status,
    required String currentUserId,
  }) {
    return StreamBuilder<int>(
      stream: _chatService.streamUnreadCount(
        requestId: requestId,
        currentUserId: currentUserId,
      ),
      builder: (context, snap) {
        final unread = snap.data ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            ElevatedButton.icon(
              onPressed: () => _openChatPage(
                requestId: requestId,
                customerId: customerId,
                providerId: providerId,
                customerName: customerName,
                customerPhone: customerPhone,
                status: status,
              ),
              icon: const Icon(Icons.chat),
              label: const Text('Chat'),
            ),
            if (unread > 0) _buildUnreadBadge(unread),
          ],
        );
      },
    );
  }

  Widget _buildNoActiveMapCard(bool isAvailable) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, color: Colors.blueGrey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isAvailable
                    ? 'You are available. Accept a request to see the job map here.'
                    : 'No current map to show right now.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivedCard({
    required String requestId,
    required String status,
    required String customerId,
    required String providerId,
    required String customerName,
    required String customerPhone,
    required String serviceAddress,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Active Job',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 12),
            _infoLine('Customer: ', customerName),
            _infoLine(
              'Location: ',
              serviceAddress.isEmpty ? 'Not provided' : serviceAddress,
            ),
            const SizedBox(height: 12),
            if (_chatService.canChatForStatus(status) &&
                customerId.isNotEmpty &&
                providerId.isNotEmpty &&
                currentUserId.isNotEmpty)
              _buildChatButton(
                requestId: requestId,
                customerId: customerId,
                providerId: providerId,
                customerName: customerName,
                customerPhone: customerPhone,
                status: status,
                currentUserId: currentUserId,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapCard({
    required String requestId,
    required String status,
    required String customerId,
    required String providerId,
    required String customerName,
    required String customerPhone,
    required String serviceAddress,
    required double? customerLat,
    required double? customerLng,
  }) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserId = currentUser?.uid ?? '';

    if (customerLat == null || customerLng == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Active Job Map',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
              const SizedBox(height: 12),
              _infoLine('Customer: ', customerName),
              _infoLine(
                'Location: ',
                serviceAddress.isEmpty ? 'Not provided' : serviceAddress,
              ),
              const SizedBox(height: 8),
              const Text('Customer location is not available for this request.'),
              const SizedBox(height: 12),
              if (_chatService.canChatForStatus(status) &&
                  customerId.isNotEmpty &&
                  providerId.isNotEmpty &&
                  currentUserId.isNotEmpty)
                _buildChatButton(
                  requestId: requestId,
                  customerId: customerId,
                  providerId: providerId,
                  customerName: customerName,
                  customerPhone: customerPhone,
                  status: status,
                  currentUserId: currentUserId,
                ),
            ],
          ),
        ),
      );
    }

    final customerLatLng = LatLng(customerLat, customerLng);

    if (_providerCurrentLatLng != null) {
      final key =
          '${_providerCurrentLatLng!.latitude},${_providerCurrentLatLng!.longitude}->${customerLatLng.latitude},${customerLatLng.longitude}';
      if (_routeKey != key && !_loadingRoute) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _loadRoute(from: _providerCurrentLatLng!, to: customerLatLng);
        });
      }
    }

    final markers = <Marker>[
      Marker(
        point: customerLatLng,
        width: 44,
        height: 44,
        child: const Icon(
          Icons.location_pin,
          color: Colors.red,
          size: 40,
        ),
      ),
    ];

    if (_providerCurrentLatLng != null) {
      markers.add(
        Marker(
          point: _providerCurrentLatLng!,
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

    final routeToDraw = _routePoints.isNotEmpty
        ? _routePoints
        : (_providerCurrentLatLng != null
        ? [_providerCurrentLatLng!, customerLatLng]
        : <LatLng>[]);

    final boundsPoints = <LatLng>[
      customerLatLng,
      if (_providerCurrentLatLng != null) _providerCurrentLatLng!,
      ..._routePoints,
    ];

    final cameraFit = boundsPoints.length >= 2
        ? CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(boundsPoints),
      padding: const EdgeInsets.all(40),
    )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Active Job Map',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
            const SizedBox(height: 12),
            _infoLine('Customer: ', customerName),
            _infoLine(
              'Location: ',
              serviceAddress.isEmpty ? 'Not provided' : serviceAddress,
            ),
            if (_loadingLocation) ...[
              const SizedBox(height: 8),
              const Text('Loading your current location...'),
            ],
            if (_locationError != null) ...[
              const SizedBox(height: 8),
              Text(
                _locationError!,
                style: const TextStyle(color: Colors.orange),
              ),
            ],
            if (_loadingRoute) ...[
              const SizedBox(height: 8),
              const Text('Loading route...'),
            ],
            if (_routeError != null) ...[
              const SizedBox(height: 8),
              Text(
                _routeError!,
                style: const TextStyle(color: Colors.orange),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: customerLatLng,
                    initialZoom: 15,
                    initialCameraFit: cameraFit,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.nepoo_fix',
                    ),
                    if (routeToDraw.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: routeToDraw,
                            strokeWidth: 5,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: markers),
                    RichAttributionWidget(
                      attributions: const [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                      showFlutterMapAttribution: false,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await _loadProviderCurrentLocation();
                    if (!mounted) return;
                    if (_providerCurrentLatLng != null) {
                      await _loadRoute(
                        from: _providerCurrentLatLng!,
                        to: customerLatLng,
                      );
                    }
                  },
                  icon: const Icon(Icons.my_location),
                  label: const Text('Refresh My Location'),
                ),
                if (_chatService.canChatForStatus(status) &&
                    customerId.isNotEmpty &&
                    providerId.isNotEmpty &&
                    currentUserId.isNotEmpty)
                  _buildChatButton(
                    requestId: requestId,
                    customerId: customerId,
                    providerId: providerId,
                    customerName: customerName,
                    customerPhone: customerPhone,
                    status: status,
                    currentUserId: currentUserId,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required String serviceType,
    required String description,
    required dynamic price,
    required bool approved,
    required bool isAvailable,
    required List<String> availableDays,
    required String startHour,
    required String endHour,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your Service Profile",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text("Service Type: $serviceType"),
            const SizedBox(height: 8),
            Text("Description: $description"),
            const SizedBox(height: 8),
            Text("Price: ${_priceText(price)}"),
            const SizedBox(height: 8),
            Text("Approval Status: ${approved ? "Approved" : "Pending"}"),
            const SizedBox(height: 8),
            Text("Availability: ${isAvailable ? "Available" : "Unavailable"}"),
            const SizedBox(height: 8),
            Text("Available Days: ${_daysText(availableDays)}"),
            const SizedBox(height: 8),
            Text("Working Hours: $startHour - $endHour"),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("No user found")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Provider Home"),
        actions: const[
          NotificationBell(),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || !snap.data!.exists || snap.data!.data() == null) {
            return const Center(child: Text("Provider data not found"));
          }

          final data = snap.data!.data()!;
          final name = data["name"]?.toString() ?? "Provider";
          final serviceType = data["serviceType"]?.toString() ?? "Not set";
          final description =
              data["serviceDescription"]?.toString() ?? "No description added";
          final price = data["pricePerHour"];
          final approved = (data["approved"] ?? false) == true;
          final isAvailable = (data["isAvailable"] ?? true) == true;
          final currentRequestId = data["currentRequestId"]?.toString() ?? '';
          final availableDays = ((data["availableDays"] ?? []) as List)
              .map((e) => e.toString())
              .toList();
          final startHour = data["startHour"]?.toString() ?? "Not set";
          final endHour = data["endHour"]?.toString() ?? "Not set";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Hello, $name",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (currentRequestId.isNotEmpty)
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('service_requests')
                        .doc(currentRequestId)
                        .snapshots(),
                    builder: (context, requestSnap) {
                      if (requestSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        );
                      }

                      if (!requestSnap.hasData ||
                          !requestSnap.data!.exists ||
                          requestSnap.data!.data() == null) {
                        return _buildNoActiveMapCard(isAvailable);
                      }

                      final requestData = requestSnap.data!.data()!;
                      final status = (requestData['status'] ?? '').toString();
                      final customerName =
                          requestData['userName']?.toString() ?? 'Customer';
                      final customerPhone =
                          requestData['userPhone']?.toString() ?? '';
                      final customerId =
                          requestData['userId']?.toString() ?? '';
                      final providerId =
                          requestData['providerId']?.toString() ?? '';
                      final serviceAddress =
                          requestData['serviceAddress']?.toString() ?? '';
                      final customerLat =
                      _toDouble(requestData['serviceLatitude']);
                      final customerLng =
                      _toDouble(requestData['serviceLongitude']);

                      if (_showMapForStatus(status)) {
                        return _buildMapCard(
                          requestId: requestSnap.data!.id,
                          status: status,
                          customerId: customerId,
                          providerId: providerId,
                          customerName: customerName,
                          customerPhone: customerPhone,
                          serviceAddress: serviceAddress,
                          customerLat: customerLat,
                          customerLng: customerLng,
                        );
                      }

                      if (_hasActiveJobWithoutMap(status)) {
                        return _buildArrivedCard(
                          requestId: requestSnap.data!.id,
                          status: status,
                          customerId: customerId,
                          providerId: providerId,
                          customerName: customerName,
                          customerPhone: customerPhone,
                          serviceAddress: serviceAddress,
                        );
                      }

                      return _buildNoActiveMapCard(isAvailable);
                    },
                  )
                else
                  _buildNoActiveMapCard(isAvailable),
                const SizedBox(height: 16),
                _buildProfileCard(
                  serviceType: serviceType,
                  description: description,
                  price: price,
                  approved: approved,
                  isAvailable: isAvailable,
                  availableDays: availableDays,
                  startHour: startHour,
                  endHour: endHour,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}