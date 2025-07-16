import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:pull_to_refresh/pull_to_refresh.dart' as ptr;
import '../services/mongodb.dart';
import 'home.dart';
import 'overview.dart';
import 'energy.dart';
import 'survey.dart';
import 'manualcontrol.dart';
import 'scheduling.dart';
import '../services/notification_service.dart' as notif;



class SummaryPage extends StatefulWidget {
  final String name;
  final String address;
  final LatLng coordinates;
  final List<dynamic> data;

  const SummaryPage({
    super.key,
    required this.name,
    required this.address,
    required this.coordinates,
    this.data = const [],
  });

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  late final String buildingName;
  List<Map<String, dynamic>> _sensorData = [];
  List<Map<String, dynamic>> _floors = [];
  List<String> _selectedFloors = [];
  String _timeRange = 'today';
  bool _isLoading = true;
  bool _isFilterLoading = false; // New loading indicator for filters
  int _selectedTab = 0;
  bool _isFilterExpanded = false;
  final notif.NotificationService _notificationService = notif.NotificationService();

  String _selectedMetric = 'energy'; // Default to 'energy'
  final ptr.RefreshController _refreshController =
  ptr.RefreshController(initialRefresh: false);

  void _showNotifications() {
    _notificationService.showNotification(
        context,
        "You are up to date",
        type: notif.NotificationType.success
    );
  }
  @override
  void initState() {
    super.initState();
    buildingName = widget.name;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _loadFloors();
      await _loadSensorData();
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFloors() async {
    try {
      final floorPlans =
      await MongoService.getFloorPlansByBuildingName(buildingName);
      setState(() {
        _floors = floorPlans.map((fp) {
          final id = fp['_id'].toString();
          return {...fp, 'id': id};
        }).toList();
        if (_floors.isNotEmpty && _selectedFloors.isEmpty) {
          _selectedFloors = _floors.map((f) => f['id'].toString()).toList();
        }
      });
      print('📄 Loaded ${_floors.length} floor plans');
    } catch (e) {
      print('Error loading floors: $e');
    }
  }

  Future<void> _loadSensorData() async {
    try {
      setState(() => _isFilterLoading = true); // Start loading indicator

      final now = DateTime.now();
      DateTime startDate;
      switch (_timeRange) {
        case 'today':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = DateTime(1900);
      }

      final rawData = await MongoService.fetchAllSensorData(
        buildingName,
        timeRange: _timeRange,
      );

      final annotated = _annotateEnergies(rawData);
      setState(() {
        _sensorData = annotated;
      });
      print(
          '🔍 Filtered to ${_sensorData.length} data points after time check');
      print(
          '🔍 Total energy after filtering: ${_calculateTotalEnergy().toStringAsFixed(2)} kWh');
    } catch (e) {
      print('❌ Error loading sensor data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    } finally {
      setState(() => _isFilterLoading = false);
    }
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }

  List<Map<String, dynamic>> _annotateEnergies(
      List<Map<String, dynamic>> data) {
    if (data.length < 2) {
      return data.map((d) {
        d['energy'] = 0.0;
        return d;
      }).toList();
    }

    final sortedData = List<Map<String, dynamic>>.from(data)
      ..sort((a, b) => _parseDateTime(a).compareTo(_parseDateTime(b)));

    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < sortedData.length; i++) {
      final current = Map<String, dynamic>.from(sortedData[i]);
      if (i > 0) {
        final prev = sortedData[i - 1];
        final dtCurrent = _parseDateTime(current);
        final dtPrev = _parseDateTime(prev);
        final currentEnergy = _toDouble(current['energy']);
        final prevEnergy = _toDouble(prev['energy']);
        final energyDiff = currentEnergy - prevEnergy;
        final durationHours =
            dtCurrent.difference(dtPrev).inSeconds / 3600.0;
        current['energy'] = energyDiff;
      } else {
        current['energy'] = 0.0;
      }
      result.add(current);
    }
    return result;
  }

  DateTime _parseDateTime(Map<String, dynamic> entry) {
    final dateStr = entry['date'] as String;
    final timeStr = entry['time'] as String;
    final full = '$dateStr $timeStr';
    return DateFormat('EEE MMM dd yyyy h:mm:ss a').parse(full);
  }

  double _calculateTotalEnergy() {
    return _sensorData.fold<double>(
      0.0,
          (sum, d) => sum + _toDouble(d['energy']),
    );
  }

  double _calculateTotalCost() {
    const pricePerKwh = 0.3;
    return _calculateTotalEnergy() * pricePerKwh;
  }

  double _calculateAvgTemp() {
    final temps = _sensorData
        .map((d) => _toDouble(d['temperature']))
        .where((t) => t > -30 && t < 60);
    return temps.isEmpty ? 0.0 : temps.reduce((a, b) => a + b) / temps.length;
  }

  double _calculateAvgHumidity() {
    final hums = _sensorData
        .map((d) => _toDouble(d['humidity']))
        .where((h) => h >= 0 && h <= 100);
    return hums.isEmpty ? 0.0 : hums.reduce((a, b) => a + b) / hums.length;
  }

  int _calculateAvgOccupancy() {
    final occs = _sensorData
        .map((d) => _toInt(d['occupancy']))
        .where((o) => o >= 0);
    return occs.isEmpty ? 0 : (occs.reduce((a, b) => a + b) / occs.length).round();
  }

  void _showFloorFilterDialog() {
    final List<String> selected = [..._selectedFloors];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.red,
      builder: (ctx) {
        double sheetHeight = 200.0; // Base height
        if (_floors.isNotEmpty) {
          double itemHeight = 80.0; // Approximate height per floor tile
          double listHeight = _floors.length * itemHeight;
          sheetHeight = 270 + listHeight; // Add header, buttons, padding
        }
        sheetHeight = sheetHeight.clamp(300.0, MediaQuery.of(context).size.height * 0.7);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: sheetHeight,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.layers_outlined,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Select Floors',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${selected.length} selected',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Quick actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                selected.clear();
                                selected.addAll(_floors.map((f) => f['id'].toString()));
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Select All',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                selected.clear();
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text(
                              'Clear All',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Floor list
                  Expanded(
                    child: _floors.isNotEmpty
                        ? ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _floors.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final floor = _floors[index];
                        final id = floor['id'].toString();
                        final name = floor['floorPlan'] ?? floor['name'] ?? 'Floor ${index + 1}';
                        final isSelected = selected.contains(id);

                        return Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF2563EB).withOpacity(0.05)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2563EB).withOpacity(0.3)
                                  : Colors.grey.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.business,
                                color: isSelected ? Colors.white : Colors.grey.shade600,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              name,
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'Floor ID: ${id.substring(0, 8)}...',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade400,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                                  : null,
                            ),
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selected.remove(id);
                                } else {
                                  selected.add(id);
                                }
                              });
                            },
                          ),
                        );
                      },
                    )
                        : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.layers_outlined,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No floors available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Apply button
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedFloors = selected;
                          });
                          Navigator.pop(context);
                          _loadSensorData();
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Apply Selection',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  ),
                ],

              ),

            );

          },
        );

      },
    );

  }


  final List<String> _tabLabels = [
    'Overview',
    'Charts',
    'Calendar',
    'Settings',
    'Survey'
  ];

  Future<void> _refreshData() async {
    try {
      await _loadData();
      _refreshController.refreshCompleted();
    } catch (e) {
      _refreshController.refreshFailed();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to refresh: $e')));
    }
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _isLoading || _isFilterLoading
            ? const Center(
            child: CircularProgressIndicator(color: Colors.blue))
            : OverviewTab(
          sensorData: _sensorData,
          calculateTotalEnergy: _calculateTotalEnergy,
          calculateTotalCost: _calculateTotalCost,
          calculateAvgTemp: _calculateAvgTemp,
          calculateAvgHumidity: _calculateAvgHumidity,
          calculateAvgOccupancy: _calculateAvgOccupancy,
          currentFilter: _timeRange,
        );
      case 1:
        return _isLoading || _isFilterLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.blue))
            : EnergyTab(
          sensorData: _sensorData,
          currentFilter: _timeRange,
          selectedMetric: _selectedMetric,
          onMetricChanged: (metric) {
            setState(() {
              _selectedMetric = metric;
              _loadSensorData();
            });
          },
        );
      case 4:
        return SurveyFeedbackTab(building: buildingName);
      case 3:
        return ManualControlTab(building: buildingName);
      case 2:
        return SchedulingTab(building: buildingName);
      default:
        return OverviewTab(
            sensorData: _sensorData,
            calculateTotalEnergy: _calculateTotalEnergy,
            calculateTotalCost: _calculateTotalCost,
            calculateAvgTemp: _calculateAvgTemp,
            calculateAvgHumidity: _calculateAvgHumidity,
            calculateAvgOccupancy: _calculateAvgOccupancy,
            currentFilter: _timeRange);
    }
  }


  Widget _buildFilterBar() {
    final isLarge = _isLargeScreen(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: 0.5,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _isFilterExpanded = !_isFilterExpanded;
                });
              },
              child: Padding(
                padding: EdgeInsets.all(_getResponsiveValue(context,
                    mobile: 14,
                    tablet: 16,
                    desktop: 18
                )),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune,
                      color: const Color(0xFF2563EB),
                      size: _getResponsiveValue(context,
                          mobile: 18,
                          tablet: 20,
                          desktop: 22
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: _getResponsiveValue(context,
                            mobile: 13,
                            tablet: 14,
                            desktop: 16
                        ),
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    if (_isFilterLoading)
                      SizedBox(
                        width: _getResponsiveValue(context,
                            mobile: 14,
                            tablet: 16,
                            desktop: 18
                        ),
                        height: _getResponsiveValue(context,
                            mobile: 14,
                            tablet: 16,
                            desktop: 18
                        ),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(
                      _isFilterExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: const Color(0xFF2563EB),
                      size: _getResponsiveValue(context,
                          mobile: 18,
                          tablet: 20,
                          desktop: 22
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isFilterExpanded)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  _getResponsiveValue(context, mobile: 14, tablet: 16, desktop: 18),
                  0,
                  _getResponsiveValue(context, mobile: 14, tablet: 16, desktop: 18),
                  _getResponsiveValue(context, mobile: 14, tablet: 16, desktop: 18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    // Floor and Time Filters on same line
                    Row(
                      children: [
                        // Floor Filter
                        Flexible(
                          flex: 3,
                          child: _buildFilterButton(
                            icon: Icons.layers_outlined,
                            label: _selectedFloors.isEmpty
                                ? 'All Floors'
                                : '${_selectedFloors.length} Floor${_selectedFloors.length > 1 ? 's' : ''}',
                            isActive: _selectedFloors.isNotEmpty,
                            onTap: _showFloorFilterDialog,
                            showBadge: _selectedFloors.isNotEmpty,
                            badgeCount: _selectedFloors.length,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Time Filter
                        Flexible(
                          flex: 2,
                          child: _buildFilterButton(
                            icon: Icons.schedule_outlined,
                            label: _getTimeRangeLabel(_timeRange),
                            isActive: _timeRange != 'all',
                            onTap: () => _showTimeFilterDialog(context),
                          ),
                        ),
                      ],
                    ),
                    // Metric Filter (only on Energy tab)
                    if (_selectedTab == 1)
                      const SizedBox(height: 8),
                    if (_selectedTab == 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Flexible(
                            flex: 2,
                            child: _buildMetricFilter(),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  Widget _buildMetricFilter() {
    return _buildFilterButton(
      icon: _getMetricIcon(_selectedMetric),
      label: _getMetricTitle(_selectedMetric),
      isActive: true, // Always active when visible
      onTap: () => _showMetricFilterDialog(context),
    );
  }
  void _showMetricFilterDialog(BuildContext context) {
    final List<Map<String, dynamic>> metrics = [
      {
        'key': 'energy',
        'label': 'Energy',
        'icon': Icons.bolt,
        'color': const Color(0xFFE74C3C),
      },
      {
        'key': 'temperature',
        'label': 'Temperature',
        'icon': Icons.thermostat,
        'color': const Color(0xFFF39C12),
      },
      {
        'key': 'humidity',
        'label': 'Humidity',
        'icon': Icons.water_drop,
        'color': const Color(0xFF3498DB),
      },
      {
        'key': 'occupancy',
        'label': 'Occupancy',
        'icon': Icons.person,
        'color': const Color(0xFF2ECC71),
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7, // Clamp height
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(Icons.tune, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    const Text(
                      'Select Metric',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...metrics.map((metric) {
                final isSelected = _selectedMetric == metric['key'];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? metric['color'].withOpacity(0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? metric['color'].withOpacity(0.3)
                          : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? metric['color'].withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? metric['color']
                              : Colors.grey.shade300,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Icon(
                        metric['icon'],
                        color: isSelected
                            ? metric['color']
                            : Colors.grey.shade600,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      metric['label'],
                      style: TextStyle(
                        fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.black : Colors.grey.shade700,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                      Icons.check,
                      color: metric['color'],
                    )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedMetric = metric['key'];
                      });
                      Navigator.pop(context);
                      _loadSensorData(); // Reload data with new metric
                    },
                  ),
                );
              }).toList(),

            ],
          ),
        )
        );
      },
    );
  }



  Widget _buildFilterButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool showBadge = false,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _getResponsiveValue(context,
              mobile: 10,
              tablet: 12,
              desktop: 14
          ),
          vertical: _getResponsiveValue(context,
              mobile: 8,
              tablet: 10,
              desktop: 12
          ),
        ),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2563EB).withOpacity(0.08)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? const Color(0xFF2563EB).withOpacity(0.2)
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: _getResponsiveValue(context,
                      mobile: 14,
                      tablet: 16,
                      desktop: 18
                  ),
                  color: isActive ? const Color(0xFF2563EB) : Colors.grey.shade600,
                ),
                if (showBadge && badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      constraints: BoxConstraints(
                        minWidth: _getResponsiveValue(context,
                            mobile: 14,
                            tablet: 16,
                            desktop: 18
                        ),
                        minHeight: _getResponsiveValue(context,
                            mobile: 14,
                            tablet: 16,
                            desktop: 18
                        ),
                      ),
                      child: Text(
                        badgeCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _getResponsiveValue(context,
                              mobile: 9,
                              tablet: 10,
                              desktop: 11
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: _getResponsiveValue(context,
                      mobile: 12,
                      tablet: 13,
                      desktop: 14
                  ),
                  fontWeight: FontWeight.w500,
                  color: isActive ? const Color(0xFF2563EB) : Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: _getResponsiveValue(context,
                  mobile: 14,
                  tablet: 16,
                  desktop: 18
              ),
              color: isActive ? const Color(0xFF2563EB) : Colors.grey.shade500,
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeRangeLabel(String range) {
    switch (range) {
      case 'today':
        return 'Today';
      case 'week':
        return 'This Week';
      case 'month':
        return 'This Month';
      case 'year':
        return 'This Year';
      case 'all':
        return 'All Time';
      default:
        return _capitalize(range);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryBlue = const Color(0xFF2563EB);
    final Color accentBlue = const Color(0xFF3B82F6);
    final Color textLight = const Color(0xFF6B7280);
    final Color white = Colors.white;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.name,
                style: const TextStyle(
                    color: Colors.black, fontSize: 18)),
            Text(widget.address,
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12)),
          ],
        ),
        actions: [
          Container(
            padding: const EdgeInsets.all(8),
            child: IconButton(
              icon: const Icon(Icons.notifications_none,
                  color: Colors.black, size: 24),
              onPressed: _showNotifications,
              tooltip: 'Notifications',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: Colors.blue))
          : ptr.SmartRefresher(
        controller: _refreshController,
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Original styled tab bar with proper sizing
              Container(
                margin: const EdgeInsets.fromLTRB(2, 16, 2, 0),
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 16,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: List.generate(_tabLabels.length, (i) {
                      final sel = i == _selectedTab;
                      return Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTab = i;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              vertical: _getResponsiveValue(context,
                                  mobile: 16,
                                  tablet: 20,
                                  desktop: 24
                              ),
                              horizontal: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: sel
                                  ? LinearGradient(
                                colors: [primaryBlue, accentBlue],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                                  : null,
                              borderRadius: BorderRadius.horizontal(
                                left: i == 0
                                    ? const Radius.circular(16)
                                    : Radius.zero,
                                right: i == _tabLabels.length - 1
                                    ? const Radius.circular(16)
                                    : Radius.zero,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _tabLabels[i],
                              style: TextStyle(
                                color: sel ? white : textLight,
                                fontSize: _getResponsiveValue(context,
                                    mobile: 12,
                                    tablet: 14,
                                    desktop: 16
                                ),
                                fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Enhanced Professional Filter Bar
              if (_selectedTab == 0 || _selectedTab == 1) ...[
                _buildFilterBar(),
                const SizedBox(height: 16),
              ],
              _buildTabContent(),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimeFilterDialog(BuildContext context) {
    final timeRanges = [
      {'key': 'today', 'label': 'Today', 'icon': Icons.today},
      {'key': 'week', 'label': 'This Week', 'icon': Icons.view_week},
      {'key': 'month', 'label': 'This Month', 'icon': Icons.calendar_month},
      {'key': 'year', 'label': 'This Year', 'icon': Icons.calendar_today},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7, // Clamp height
            ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),

          ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.schedule_outlined,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Select Time Range',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Time range options
              ...timeRanges.map((range) {
                final isSelected = _timeRange == range['key'];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF2563EB).withOpacity(0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF2563EB).withOpacity(0.3)
                          : Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        range['icon'] as IconData,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      range['label'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    trailing: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade400,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : null,
                    ),
                    onTap: () {
                      setState(() {
                        _timeRange = range['key'] as String;
                      });
                      Navigator.pop(context);
                      _loadSensorData();
                    },
                  ),
                );
              }).toList(),

            ],
          ),
        )
        );
      },
    );

  }
  IconData _getMetricIcon(String metric) {
    switch (metric) {
      case 'energy':
        return Icons.bolt;
      case 'temperature':
        return Icons.thermostat;
      case 'humidity':
        return Icons.water_drop;
      case 'occupancy':
        return Icons.person;
      default:
        return Icons.bolt;
    }
  }

  String _getMetricTitle(String metric) {
    switch (metric) {
      case 'energy':
        return 'Energy';
      case 'temperature':
        return 'Temperature';
      case 'humidity':
        return 'Humidity';
      case 'occupancy':
        return 'Occupancy';
      default:
        return 'Energy';
    }
  }

  Color _getMetricColor(String metric) {
    switch (metric) {
      case 'energy':
        return const Color(0xFFE74C3C);
      case 'temperature':
        return const Color(0xFFF39C12);
      case 'humidity':
        return const Color(0xFF3498DB);
      case 'occupancy':
        return const Color(0xFF2ECC71);
      default:
        return const Color(0xFFE74C3C);
    }
  }


  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

}
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }

}
double _getResponsiveValue(BuildContext context, {
  required double mobile,
  required double tablet,
  required double desktop,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;

  // Height scaling factor (1.0 for screens ~800px height, scales up for taller screens)
  final heightScaleFactor = (screenHeight / 800).clamp(0.8, 1.5);

  double baseValue;
  if (screenWidth < 600) {
    baseValue = mobile;
  } else if (screenWidth < 1200) {
    baseValue = tablet;
  } else {
    baseValue = desktop;
  }

  // Apply height scaling
  return baseValue * heightScaleFactor;
}
bool _isLargeScreen(BuildContext context) {
  return MediaQuery.of(context).size.width > 800;
}