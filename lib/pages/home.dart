import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/mongodb.dart';
import 'summary.dart'; // your separate summary page
import '../services/notification_service.dart' as notif;
import 'package:flutter_map_cache/flutter_map_cache.dart'; // Corrected import

class LocationData {
  final String name;
  final String address;
  final LatLng coordinates;
  LocationData({
    required this.name,
    required this.address,
    required this.coordinates,
  });
  factory LocationData.fromMap(Map<String, dynamic> doc) {
    final loc = doc['location'] as List<dynamic>? ?? [0.0, 0.0];
    return LocationData(
      name: doc['buildingName'] as String? ?? 'Unknown',
      address: doc['address'] as String? ?? 'No address',
      coordinates: LatLng((loc[0] as num).toDouble(), (loc[1] as num).toDouble()),
    );
  }
}

// Responsive Scale Helper
double responsiveScale(BuildContext context, double baseSize, {double minScale = 0.8, double maxScale = 1.2}) {
  double screenWidth = MediaQuery.of(context).size.width;
  double scale = screenWidth / 375; // Base is iPhone-like width
  return baseSize * scale.clamp(minScale, maxScale);
}

class HomePage extends StatefulWidget {
  final String userId;
  const HomePage({super.key, required this.userId});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  LatLng? _currentPosition;
  final MapController _mapController = MapController();
  bool _isLoading = true, _showMap = false;
  String _statusMessage = "Initializing...";
  List<LocationData> _locations = [];
  OverlayEntry? _currentOverlayEntry;
  final notif.NotificationService _notificationService = notif.NotificationService();
  String _searchQuery = '';
  bool _sortByDistance = false;
  List<LocationData> _filteredLocations = [];

  @override
  void initState() {
    super.initState();
    _initAndLoad();
    Future.delayed(const Duration(milliseconds: 500), _determinePosition);
  }

  void _showNotifications() {
    _notificationService.showNotification(
      context,
      "You are up to date",
      type: notif.NotificationType.success,
    );
  }

  Future<void> _initAndLoad() async {
    await MongoService.init();
    final docs = await MongoService.getBuildingsByUserId(widget.userId);
    setState(() {
      _locations = docs.cast<LocationData>();
      _filteredLocations = [..._locations];
      _isLoading = false;
    });
  }

  void _updateFilteredLocations() {
    List<LocationData> filtered = _locations;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((loc) =>
          loc.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    if (_sortByDistance && _currentPosition != null) {
      filtered.sort((a, b) {
        double distA = _calculateDistance(_currentPosition!, a.coordinates);
        double distB = _calculateDistance(_currentPosition!, b.coordinates);
        return distA.compareTo(distB);
      });
    }
    setState(() {
      _filteredLocations = filtered;
    });
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const double earthRadius = 6371; // km
    final lat1 = from.latitude;
    final lon1 = from.longitude;
    final lat2 = to.latitude;
    final lon2 = to.longitude;
    final dLat = radians(lat2 - lat1);
    final dLon = radians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(radians(lat1)) *
            cos(radians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double radians(double degrees) => degrees * (pi / 180);

  Future<void> _determinePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return _showFallbackMap();
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) return _showFallbackMap();
    final pos = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(pos.latitude, pos.longitude);
      _isLoading = false;
    });
  }

  void _showFallbackMap() => setState(() {
    _currentPosition = const LatLng(1.307056, 103.780675);
    _isLoading = false;
  });

  void _toggleMapView() {
    if (_locations.isEmpty) return;
    setState(() {
      _showMap = !_showMap;
      _currentPosition = _locations.first.coordinates;
    });
  }

  void _onLogoutPressed() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('userToken');
                print('🗑️ [HomePage] Token removed successfully');
                _notificationService.showNotification(
                  context,
                  'Successfully Logged out',
                  type: notif.NotificationType.success,
                );
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AuthenticationWrapper(),
                  ),
                      (_) => false,
                );
              } catch (e) {
                print('❌ [HomePage] Logout failed: $e');
                _notificationService.showNotification(
                  context,
                  'Failed to Log out',
                  type: notif.NotificationType.error,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => FilterBottomSheet(
        searchQuery: _searchQuery,
        sortByDistance: _sortByDistance,
        currentPosition: _currentPosition,
        onApply: (searchQuery, sortByDistance) {
          setState(() {
            _searchQuery = searchQuery;
            _sortByDistance = sortByDistance;
          });
          _updateFilteredLocations();
        },
      ),
    );
  }

  void _onRetryPressed() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Retrying...";
    });
    await _initAndLoad();
  }

  @override
  void dispose() {
    _currentOverlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double scale = MediaQuery.of(context).textScaleFactor;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Locations',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: responsiveScale(context, 20) * scale,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: _showMap
            ? IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => setState(() => _showMap = false),
        )
            : IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(Icons.logout, color: Colors.black, size: responsiveScale(context, 24)),
          onPressed: _onLogoutPressed,
        ),
        actions: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(Icons.notifications_none, color: Colors.black, size: responsiveScale(context, 24)),
            onPressed: _showNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoading(context)
          : _showMap
          ? _buildMapView(context)
          : _buildLocationsList(context),
    );
  }

  Widget _buildLoading(BuildContext context) {
    double scale = MediaQuery.of(context).textScaleFactor;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue),
          SizedBox(height: responsiveScale(context, 20)),
          Text(
            _statusMessage,
            style: TextStyle(fontSize: responsiveScale(context, 16) * scale),
          ),
          SizedBox(height: responsiveScale(context, 20)),
          ElevatedButton.icon(
            onPressed: _showFallbackMap,
            icon: Icon(Icons.location_off, size: responsiveScale(context, 16)),
            label: Text("Skip location detection"),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsList(BuildContext context) {
    double scale = MediaQuery.of(context).textScaleFactor;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(responsiveScale(context, 16)),
            child: Column(
              children: [
                Expanded(
                  child: _filteredLocations.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No buildings found',
                          style: TextStyle(
                            fontSize: responsiveScale(context, 18) * scale,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: responsiveScale(context, 20)),
                        ElevatedButton.icon(
                          onPressed: _onRetryPressed,
                          icon: Icon(Icons.refresh, color: Colors.white, size: responsiveScale(context, 18)),
                          label: Text(
                            "Retry",
                            style: TextStyle(
                              fontSize: responsiveScale(context, 16) * scale,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(responsiveScale(context, 12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _filteredLocations.length,
                    itemBuilder: (ctx, i) => _siteCard(_filteredLocations[i], context),
                  ),
                ),
                SizedBox(height: responsiveScale(context, 8)),
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.45,
                  height: responsiveScale(context, 45),
                  child: ElevatedButton.icon(
                    onPressed: _showFilterBottomSheet,
                    icon: Icon(Icons.filter_alt, color: Colors.black, size: responsiveScale(context, 20)),
                    label: Text(
                      "Filter",
                      style: TextStyle(
                        fontSize: responsiveScale(context, 15) * scale,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(responsiveScale(context, 12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: responsiveScale(context, 16), vertical: responsiveScale(context, 0)),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.45,
            height: responsiveScale(context, 45),
            child: ElevatedButton.icon(
              onPressed: _toggleMapView,
              icon: Icon(Icons.map, color: Colors.white, size: responsiveScale(context, 20)),
              label: Text(
                "Map",
                style: TextStyle(
                  fontSize: responsiveScale(context, 15) * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(responsiveScale(context, 12)),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: responsiveScale(context, 35)),
      ],
    );
  }

  Widget _siteCard(LocationData loc, BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;

    // Adjust these values based on your preference
    final double paddingSize = screenHeight > 800 ? 20 : 12;
    final double titleFontSize = screenHeight > 800 ? 20 : 16;
    final double summaryFontSize = screenHeight > 800 ? 14 : 12;
    final double iconSize = screenHeight > 800 ? 18 : 14;

    return Container(
      margin: EdgeInsets.only(bottom: screenHeight > 800 ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(screenHeight > 800 ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(screenHeight > 800 ? 0.15 : 0.1),
            blurRadius: screenHeight > 800 ? 10 : 6,
            spreadRadius: screenHeight > 800 ? 2 : 1,
            offset: Offset(0, screenHeight > 800 ? 4 : 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(paddingSize),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize * 1.1  * MediaQuery.of(context).textScaleFactor,
                fontFamily: 'Poppins',
              ),
            ),
            SizedBox(height: screenHeight > 800 ? 10 : 4),
            Text(
                loc.address,
                style: TextStyle(
                  fontSize: titleFontSize * 0.88
                ),
            ),
            SizedBox(height: screenHeight > 800 ? 12 : 6),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SummaryPage(
                      name: loc.name,
                      address: loc.address,
                      coordinates: loc.coordinates,
                      data: [],
                    ),
                  ),
                ),
                icon: Icon(Icons.bar_chart, size: iconSize),
                label: Text(
                  "Summary",
                  style: TextStyle(fontSize: summaryFontSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            center: _currentPosition ?? const LatLng(1.3096, 103.77),
            zoom: 15,
            onTap: (_, __) {
              _currentOverlayEntry?.remove();
              _currentOverlayEntry = null;
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              // Add this line to include a custom user-agent
              userAgentPackageName: 'com.example.bmsapp', // Replace with your actual package name
            ),
            MarkerLayer(
              markers: [
                if (_currentPosition != null)
                  Marker(
                    point: _currentPosition!,
                    width: responsiveScale(context, 80),
                    height: responsiveScale(context, 80),
                    child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                  ),
                ..._locations.map((loc) => Marker(
                  point: loc.coordinates,
                  width: responsiveScale(context, 40),
                  height: responsiveScale(context, 40),
                  child: GestureDetector(
                    onTap: () => _showBuildingPopup(context, loc),
                    child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                  ),
                )),
              ],
            ),
          ],
        ),
      ],
    );
  }

  void _showBuildingPopup(BuildContext ctx, LocationData b) {
    _currentOverlayEntry?.remove();
    final pos = _mapController.latLngToScreenPoint(b.coordinates);
    _currentOverlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: pos.x - responsiveScale(ctx, 125),
        top: pos.y - responsiveScale(ctx, 180),
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {}, // eat taps
            child: Container(
              width: responsiveScale(ctx, 250),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(responsiveScale(ctx, 12)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: responsiveScale(ctx, 10))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: EdgeInsets.all(responsiveScale(ctx, 12)),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(responsiveScale(ctx, 12))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.name,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _currentOverlayEntry?.remove();
                          _currentOverlayEntry = null;
                        },
                        child: Icon(Icons.close, size: responsiveScale(ctx, 18)),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(responsiveScale(ctx, 12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: responsiveScale(ctx, 12)),
                      ElevatedButton(
                        onPressed: () {
                          _currentOverlayEntry?.remove();
                          _currentOverlayEntry = null;
                          Navigator.push(
                            ctx,
                            MaterialPageRoute(
                              builder: (_) => SummaryPage(
                                name: b.name,
                                address: b.address,
                                coordinates: b.coordinates,
                                data: [],
                              ),
                            ),
                          );
                        },
                        child: const Text('View Building Summary'),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context)!.insert(_currentOverlayEntry!);
  }
}

// Filter Bottom Sheet Widget
class FilterBottomSheet extends StatefulWidget {
  final String searchQuery;
  final bool sortByDistance;
  final LatLng? currentPosition;
  final Function(String searchQuery, bool sortByDistance) onApply;
  const FilterBottomSheet({
    super.key,
    required this.searchQuery,
    required this.sortByDistance,
    required this.currentPosition,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late TextEditingController _searchController;
  late bool _sortByDistance;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _sortByDistance = widget.sortByDistance;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onResetPressed() {
    _searchController.clear();
    setState(() {
      _sortByDistance = false;
    });
    widget.onApply('', false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    double scale = MediaQuery.of(context).textScaleFactor;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: EdgeInsets.all(responsiveScale(context, 24)),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: responsiveScale(context, 40),
                height: responsiveScale(context, 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(responsiveScale(context, 2)),
                ),
              ),
            ),
            SizedBox(height: responsiveScale(context, 20)),
            Text(
              'Filter Buildings',
              style: TextStyle(
                fontSize: responsiveScale(context, 24) * scale,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: responsiveScale(context, 24)),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by name',
                prefixIcon: Icon(Icons.search, size: responsiveScale(context, 20)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(responsiveScale(context, 12)),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            SizedBox(height: responsiveScale(context, 20)),
            if (widget.currentPosition != null)
              Row(
                children: [
                  Checkbox(
                    value: _sortByDistance,
                    onChanged: (value) {
                      setState(() {
                        _sortByDistance = value!;
                      });
                    },
                  ),
                  Text(
                    'Sort by distance',
                    style: TextStyle(fontSize: responsiveScale(context, 16) * scale),
                  ),
                ],
              ),
            SizedBox(height: responsiveScale(context, 24)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _sortByDistance = false;
                      });
                      widget.onApply('', false);
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: responsiveScale(context, 16)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(responsiveScale(context, 12))),
                    ),
                    child: Text('Reset'),
                  ),
                ),
                SizedBox(width: responsiveScale(context, 16)),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_searchController.text, _sortByDistance);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: responsiveScale(context, 16)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(responsiveScale(context, 12)),
                      ),
                    ),
                    child: Text(
                      'Apply Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: responsiveScale(context, 16)),
          ],
        ),
      ),
    );
  }
}
