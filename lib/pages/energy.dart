import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/mongodb.dart';
import 'dart:math' as math;

class EnergyTab extends StatefulWidget {
  final List<Map<String, dynamic>> sensorData;
  final String currentFilter;
  final String selectedMetric;
  final Function(String) onMetricChanged;
  final String building;

  const EnergyTab({
    super.key,
    required this.sensorData,
    required this.currentFilter,
    required this.selectedMetric,
    required this.onMetricChanged,
    required this.building,
  });

  @override
  State<EnergyTab> createState() => _EnergyTabState();
}

class _EnergyTabState extends State<EnergyTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  String _selectedMetric = 'energy';
  final List<String> _availableMetrics = [
    'energy',
    'temperature',
    'humidity',
    'occupancy'
  ];
  bool _showEnergySavings = false;

  // NEW STATE VARIABLES for aggregated predicted energy
  // Stores 30-minute aggregated predictions for 'today' view (Key: "YYYY-MM-DD HH:MM")
  Map<String, double> _aggregatedPredicted30MinEnergy = {};
  // Stores daily aggregated predictions for 'week'/'month' views (Key: "EEE MMM dd yyyy")
  Map<String, double> _aggregatedPredictedDailyEnergy = {};
  // Stores monthly aggregated predictions for 'year' view (Key: "MMM yyyy")
  Map<String, double> _aggregatedPredictedMonthlyEnergy = {};

  bool _isLoadingPredictions = false;

  // Consistent color scheme
  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _cardBorderColor = Color(0xFF2563EB);
  static const Color _titleColor = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
    _selectedMetric = widget.selectedMetric;
    if (_selectedMetric == 'energy') {
      _fetchPredictedEnergyData();
    }
  }

  // MODIFIED: _fetchPredictedEnergyData to aggregate predictions based on filter
  Future<void> _fetchPredictedEnergyData() async {
    if (_isLoadingPredictions) return; // Prevent multiple fetches

    setState(() {
      _isLoadingPredictions = true;
      // Clear all previous aggregations before fetching new data
      _aggregatedPredicted30MinEnergy = {};
      _aggregatedPredictedDailyEnergy = {};
      _aggregatedPredictedMonthlyEnergy = {};
    });

    try {
      List<Map<String, dynamic>> fetchedData;
      final buildingLower = widget.building.toLowerCase();

      // Use the specific fetch method based on the building name
      if (buildingLower == 'w512') {
        fetchedData = await MongoService.fetchPredictedEnergyW512(timeRange: widget.currentFilter);
      } else if (buildingLower == 'spgg') {
        fetchedData = await MongoService.fetchPredictedEnergySPGG(timeRange: widget.currentFilter);
      } else {
        // Fallback or error for unknown buildings
        print('⚠️ No predicted energy data service for building: ${widget.building}');
        fetchedData = [];
      }

      // Process fetchedData to aggregate based on the current filter
      if (widget.currentFilter == 'today') {
        // For 'today' filter, aggregate predictions by 30-minute intervals
        for (var doc in fetchedData) {
          final predEnergyMap = doc['predicted_energy'] as Map<String, dynamic>?;
          if (predEnergyMap != null && predEnergyMap['date'] != null) {
            try {
              final String datePart = predEnergyMap['date'] as String; // e.g., "Wed Jul 25 2025"

              // Iterate through specific 30-minute prediction keys
              predEnergyMap.forEach((key, value) {
                if (key.contains(':') && key.contains('M') && key != 'time' && key != 'id' && key != 'timestamp' && key != 'total_30min') {
                  try {
                    final String timePart = key; // e.g., "7:55:25 PM"
                    final double energyValue = _toDouble(value);

                    // Combine date and time, then parse to get local DateTime
                    final predictedDateTime = DateFormat('EEE MMM dd yyyy h:mm:ss a').parse('$datePart $timePart');

                    // Normalize to the start of the 30-minute interval
                    final normalizedMinute = (predictedDateTime.minute ~/ 30) * 30;
                    final intervalStart = DateTime(
                      predictedDateTime.year,
                      predictedDateTime.month,
                      predictedDateTime.day,
                      predictedDateTime.hour,
                      normalizedMinute,
                    );

                    final thirtyMinKey = DateFormat('yyyy-MM-dd HH:mm').format(intervalStart);

                    _aggregatedPredicted30MinEnergy.update(
                      thirtyMinKey,
                          (existingSum) => existingSum + energyValue,
                      ifAbsent: () => energyValue,
                    );
                  } catch (e) {
                    print('Error processing individual 30-min prediction for today: $key - $e');
                  }
                }
              });
            } catch (e) {
              print('Error processing predicted data for today aggregation: $e');
            }
          }
        }
        print('DEBUG: Aggregated 30-Min Predictions (Today): $_aggregatedPredicted30MinEnergy');
      } else if (widget.currentFilter == 'week' || widget.currentFilter == 'month') {
        // For 'week' or 'month' filters, aggregate predictions by day (Key: "EEE MMM dd yyyy")
        for (var doc in fetchedData) {
          final predEnergyMap = doc['predicted_energy'] as Map<String, dynamic>?;
          if (predEnergyMap != null && predEnergyMap['date'] != null) {
            final date = predEnergyMap['date'] as String; // e.g., "Wed Jul 25 2025"
            final total30min = _toDouble(predEnergyMap['total_30min']);

            _aggregatedPredictedDailyEnergy.update(
              date,
                  (existingSum) => existingSum + total30min,
              ifAbsent: () => total30min,
            );
          }
        }
        print('DEBUG: Aggregated Daily Predictions: $_aggregatedPredictedDailyEnergy');
      } else if (widget.currentFilter == 'year') {
        // For 'year' filter, aggregate predictions by month (Key: "MMM yyyy")
        for (var doc in fetchedData) {
          final predEnergyMap = doc['predicted_energy'] as Map<String, dynamic>?;
          if (predEnergyMap != null && doc['timestamp'] != null) {
            try {
              final predictedTimestamp = DateTime.parse(doc['timestamp']);
              final total30min = _toDouble(predEnergyMap['total_30min']);
              final monthlyKey = DateFormat('MMM yyyy').format(predictedTimestamp); // e.g., "Jul 2025"

              _aggregatedPredictedMonthlyEnergy.update(
                monthlyKey,
                    (existingSum) => existingSum + total30min,
                ifAbsent: () => total30min,
              );
            } catch (e) {
              print('Error processing predicted data for monthly aggregation: $e');
            }
          }
        }
        print('DEBUG: Aggregated Monthly Predictions: $_aggregatedPredictedMonthlyEnergy');
      }

      setState(() {
        _isLoadingPredictions = false;
      });
      print('✅ Fetched and processed predicted energy data: ${fetchedData.length} records');
    } catch (e) {
      print('❌ Error fetching predicted energy data: $e');
      setState(() {
        _isLoadingPredictions = false;
        // Optionally clear data or show an error state
        _aggregatedPredicted30MinEnergy = {};
        _aggregatedPredictedDailyEnergy = {};
        _aggregatedPredictedMonthlyEnergy = {};
      });
    }
  }


  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EnergyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-fetch predictions if metric changes to energy or if filter changes
    if (widget.selectedMetric != oldWidget.selectedMetric) {
      setState(() {
        _selectedMetric = widget.selectedMetric;
        if (_selectedMetric == 'energy') {
          _fetchPredictedEnergyData(); // Fetch when switching to energy
        } else {
          // Clear predicted data if not on energy tab
          _aggregatedPredicted30MinEnergy = {};
          _aggregatedPredictedDailyEnergy = {};
          _aggregatedPredictedMonthlyEnergy = {};
        }
      });
    } else if (widget.currentFilter != oldWidget.currentFilter && _selectedMetric == 'energy') {
      _fetchPredictedEnergyData(); // Re-fetch if time filter changes for energy tab
    }
    print('DEBUG: Predicted data count (30-min): ${_aggregatedPredicted30MinEnergy.length}');
    print('DEBUG: Predicted data count (daily): ${_aggregatedPredictedDailyEnergy.length}');
    print('DEBUG: Predicted data count (monthly): ${_aggregatedPredictedMonthlyEnergy.length}');
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    double result;
    if (value is double) {
      result = value;
    } else if (value is int) {
      result = value.toDouble();
    } else if (value is String) {
      final parsed = double.tryParse(value);
      result = parsed ?? 0.0;
    } else {
      result = 0.0;
    }
    // Cap energy values at 0 (no negative values)
    return result < 0 ? 0.0 : result;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }

  List<Map<String, dynamic>> _getAggregatedReadings() {
    if (widget.sensorData.isEmpty) return [];
    switch (widget.currentFilter) {
      case 'today':
        return _get30MinuteReadings(); // Changed to 30-minute granularity
      case 'week':
      case 'month':
        return _getDailyReadings();
      case 'year':
        return _getMonthlyReadings();
      default:
        return _get30MinuteReadings(); // Default to 30-minute
    }
  }

  // NEW: _get30MinuteReadings for 'today' filter
  List<Map<String, dynamic>> _get30MinuteReadings() {
    if (widget.sensorData.isEmpty) return [];
    final currentEntries = widget.sensorData.where((entry) {
      final now = DateTime.now();
      final today = DateFormat('EEE MMM dd yyyy').format(now);
      return entry['date'] == today;
    }).toList();
    if (currentEntries.isEmpty) return [];

    final targetDate = DateFormat('EEE MMM dd yyyy').parse(currentEntries.first['date']);
    final thirtyMinuteSlots = <String, List<Map<String, dynamic>>>{};

    // Initialize 48 30-minute slots for the day
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        final slotStart = DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);
        final key = DateFormat('yyyy-MM-dd HH:mm').format(slotStart);
        thirtyMinuteSlots[key] = [];
      }
    }

    // Distribute sensor data into 30-minute slots
    for (var entry in currentEntries) {
      try {
        final entryTime = DateFormat('EEE MMM dd yyyy h:mm:ss a').parse('${entry['date']} ${entry['time']}');
        final normalizedMinute = (entryTime.minute ~/ 30) * 30;
        final slotStart = DateTime(
          entryTime.year,
          entryTime.month,
          entryTime.day,
          entryTime.hour,
          normalizedMinute,
        );
        final key = DateFormat('yyyy-MM-dd HH:mm').format(slotStart);
        thirtyMinuteSlots[key]?.add(entry);
      } catch (e) {
        print('Error parsing sensor data entry time: $e');
      }
    }

    // Convert to a list of maps, ensuring all 48 slots are present
    final List<Map<String, dynamic>> result = [];
    final now = DateTime.now();
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        final slotStart = DateTime(targetDate.year, targetDate.month, targetDate.day, hour, minute);
        // Only include slots up to the current 30-minute interval
        if (slotStart.isBefore(now.add(const Duration(minutes: 30)))) {
          final key = DateFormat('yyyy-MM-dd HH:mm').format(slotStart);
          final entries = thirtyMinuteSlots[key] ?? [];
          final hasData = entries.isNotEmpty;

          result.add({
            'date': DateFormat('EEE MMM dd yyyy').format(slotStart),
            'timeRange': DateFormat('HH:mm').format(slotStart), // e.g., "08:00"
            'displayLabel': DateFormat('HH:mm').format(slotStart), // e.g., "08:00"
            'energy': hasData
                ? entries.fold(0.0, (sum, e) => sum + _toDouble(e['energy']))
                : 0.0,
            'temperature': hasData
                ? entries.map((e) => _toDouble(e['temperature'])).average
                : 0.0,
            'humidity': hasData
                ? entries.map((e) => _toDouble(e['humidity'])).average
                : 0.0,
            'occupancy': hasData
                ? entries.fold(0, (sum, e) => sum + _toInt(e['occupancy']))
                : 0,
          });
        }
      }
    }
    return result;
  }


  List<Map<String, dynamic>> _getDailyReadings() {
    if (widget.sensorData.isEmpty) return [];
    final DateTime now = DateTime.now();
    late DateTime startDate;
    int daysToInclude;
    switch (widget.currentFilter) {
      case 'week':
        daysToInclude = 7;
        startDate = now.subtract(const Duration(days: 6));
        break;
      case 'month':
        daysToInclude = 30;
        startDate = now.subtract(const Duration(days: 29));
        break;
      default:
        return [];
    }
    final dateRange = List<DateTime>.generate(
      daysToInclude,
          (i) =>
          DateTime(startDate.year, startDate.month, startDate.day).add(Duration(days: i)),
    );
    final dailyData = <String, List<Map<String, dynamic>>>{};
    for (final entry in widget.sensorData) {
      try {
        final entryDateString = entry['date'] as String;
        final parsedDate = DateFormat('EEE MMM dd yyyy').parse(entryDateString);
        final normalizedDateString = DateFormat('EEE MMM dd yyyy').format(parsedDate);
        dailyData.putIfAbsent(normalizedDateString, () => []).add(entry);
      } catch (e) {
        // Handle parsing errors
      }
    }
    return dateRange.map((date) {
      final formattedDate = DateFormat('EEE MMM dd yyyy').format(date);
      final entries = dailyData[formattedDate] ?? [];
      return {
        'date': formattedDate, // e.g., "Wed Jul 25 2025"
        'formattedDate': DateFormat('MMM d').format(date),
        'displayLabel': DateFormat('MMM d').format(date),
        'parsedDate': date,
        'energy': entries.fold<double>(0.0, (sum, e) => sum + _toDouble(e['energy'])),
        'temperature': entries.isEmpty
            ? 0.0
            : entries.map((e) => _toDouble(e['temperature'])).average,
        'humidity': entries.isEmpty
            ? 0.0
            : entries.map((e) => _toDouble(e['humidity'])).average,
        'occupancy': entries.fold<int>(0, (sum, e) => sum + _toInt(e['occupancy'])),
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getMonthlyReadings() {
    if (widget.sensorData.isEmpty) return [];
    final dataByMonth = <String, List<Map<String, dynamic>>>{};
    for (var entry in widget.sensorData) {
      try {
        final entryDate = DateFormat('EEE MMM dd yyyy').parse(entry['date'] as String);
        final monthKey = DateFormat('yyyy-MM').format(entryDate);
        dataByMonth.putIfAbsent(monthKey, () => []).add(entry);
      } catch (e) {
        // Handle parsing errors
      }
    }
    DateTime now = DateTime.now();
    List<DateTime> months = [];
    DateTime currentDate = DateTime(now.year, now.month, 1);
    for (int i = 0; i < 12; i++) {
      months.add(currentDate);
      currentDate = DateTime(currentDate.year, currentDate.month - 1, 1);
    }
    months = months.reversed.toList();
    return months.map((monthStart) {
      final monthKey = DateFormat('MMM yyyy').format(monthStart); // e.g., "Jul 2025"
      final entries = dataByMonth[DateFormat('yyyy-MM').format(monthStart)] ?? [];
      return {
        'month': monthStart,
        'formattedDate': DateFormat('MMM yyyy').format(monthStart),
        'displayLabel': DateFormat('MMM').format(monthStart),
        'energy': entries.fold(0.0, (sum, e) => sum + _toDouble(e['energy'])),
        'temperature': entries.isNotEmpty
            ? entries.map((e) => _toDouble(e['temperature'])).average
            : 0.0,
        'humidity': entries.isNotEmpty
            ? entries.map((e) => _toDouble(e['humidity'])).average
            : 0.0,
        'occupancy': entries.fold(0, (sum, e) => sum + _toInt(e['occupancy'])),
      };
    }).toList();
  }

  // Graph line color changes based on metric
  Color _getGraphLineColor(String metric) {
    switch (metric) {
      case 'energy':
        return const Color(0xFF3498DB);
      case 'temperature':
        return const Color(0xFFE74C3C);
      case 'humidity':
        return const Color(0xFF1ABC9C);
      case 'occupancy':
        return const Color(0xFFFF9800);
      default:
        return const Color(0xFF3498DB);
    }
  }

  String _getMetricUnit(String metric) {
    switch (metric) {
      case 'energy':
        return 'kWh';
      case 'temperature':
        return '°C';
      case 'humidity':
        return '%';
      case 'occupancy':
        return 'people';
      default:
        return '';
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
        return 'Consumption';
    }
  }

  @override
  Widget build(BuildContext context) {
    print("📊 [EnergyTab] Building tab with filter: ${widget.currentFilter}");
    print("📊 [EnergyTab] Total sensor data received: ${widget.sensorData.length} entries");

    final aggregatedData = _getAggregatedReadings();

    print("📊 [EnergyTab] Aggregated data count after processing: ${aggregatedData.length}");

    if (aggregatedData.isEmpty) {
      print("⚠️ [EnergyTab] No data available after aggregation.");
      return _buildEmptyState(context);
    }

    return _buildDataCard(context, aggregatedData);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),

        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const SizedBox(height: 24),
            Text(
              'No Data Available',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Try selecting a different time range or try again',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(BuildContext context, List<Map<String, dynamic>> data) {
    final total = data.fold<double>(
        0.0, (sum, d) => sum + _toDouble(d[_selectedMetric]));
    final average = data.isEmpty ? 0.0 : total / data.length;
    final peak = data.isEmpty
        ? 0.0
        : data.map((d) => _toDouble(d[_selectedMetric])).reduce(math.max);
    final unit = _getMetricUnit(_selectedMetric);
    final maxValue = _getMaxValue(data, _selectedMetric);
    final graphLineColor = _getGraphLineColor(_selectedMetric);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          border: Border.all(color: _primaryColor.withOpacity(0.1), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Graph Title
            // Graph Title with AI Savings Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_getMetricTitle(_selectedMetric)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: MediaQuery.of(context).size.width * 0.045, // 4.5% of screen width
                      ),
                    ),
                  ),
                ),
                // Only show for energy metric
                if (_selectedMetric == 'energy')
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showEnergySavings = !_showEnergySavings;
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.032, // ~12-16px depending on screen
                        vertical: MediaQuery.of(context).size.width * 0.016,   // ~6-8px depending on screen
                      ),
                      decoration: BoxDecoration(
                        color: _showEnergySavings ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _showEnergySavings ? Colors.orange : Colors.grey,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.eco_outlined,
                            size: MediaQuery.of(context).size.width * 0.042, // ~15-18px depending on screen
                            color: _showEnergySavings ? Colors.orange : Colors.grey,
                          ),
                          SizedBox(width: MediaQuery.of(context).size.width * 0.016), // ~6px
                          Text(
                            'AI Savings',
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width * 0.032, // ~12-14px depending on screen
                              fontWeight: FontWeight.w500,
                              color: _showEnergySavings ? Colors.orange : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            if (_showEnergySavings && _selectedMetric == 'energy') ...[
              const SizedBox(height: 16),
              _buildEnergySavingsCard(),
            ],
            const SizedBox(height: 16),
            // Line Chart
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.25, // 40% of screen height
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return LineChart(_buildLineChartData(data, maxValue, graphLineColor));
                },
              ),
            ),
            const SizedBox(height: 24),
            // Summary Cards
            _buildSummaryCards(total, average, peak, unit),
          ],
        ),
      ),
    );
  }
  Widget _buildEnergySavingsCard() {
    final savings = _calculateEnergySavings();
    final totalSavings = savings['totalSavings']!;
    final percentageSavings = savings['percentageSavings']!;

    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 16 to 12
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12), // Reduced from 16 to 12
        color: Colors.white, // Changed to white background
        border: Border.all(color: Colors.black.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [

              const SizedBox(height: 6), // Reduced from 8 to 6
              Text(
                'AI Predicted Savings: ${percentageSavings.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width * 0.037, // Dynamic font size
                  fontWeight: FontWeight.w700,
                  color: percentageSavings >= 0 ? Colors.green : Colors.red,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Icon(Icons.trending_down_outlined, color: percentageSavings >= 0 ? Colors.green : Colors.red, size: 20), // Reduced from 24 to 20
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildSummaryCards(double total, double average, double peak, String unit) {
    String formatValue(double value) {
      // Round for occupancy, else keep 2 decimals
      return unit == 'people' ? value.round().toString() : value.toStringAsFixed(2);
    }

    // Determine the first card title based on metric
    String firstCardTitle;
    double firstCardValue;
    IconData firstCardIcon;

    if (_selectedMetric == 'temperature' || _selectedMetric == 'humidity') {
      firstCardTitle = 'Lowest';
      // Find minimum value
      final data = _getAggregatedReadings();
      firstCardValue = data.isEmpty ? 0.0 : data.map((d) => _toDouble(d[_selectedMetric])).reduce(math.min);
      firstCardIcon = Icons.south_outlined;
    } else {
      firstCardTitle = 'Total';
      firstCardValue = total;
      firstCardIcon = Icons.summarize_outlined;
    }

    return Row(
      children: [
        Expanded(
          child: _buildInfoCard(
              firstCardTitle, '${formatValue(firstCardValue)} $unit', firstCardIcon),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
              'Average', '${formatValue(average)} $unit', Icons.trending_up_outlined),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildInfoCard(
              'Peak', '${formatValue(peak)} $unit', Icons.flash_on_outlined),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white,
        border: Border.all(color: _cardBorderColor.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 24, color: _primaryColor),
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.03, // Responsive font size
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width * 0.032, // Responsive font size
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartData _buildLineChartData(
      List<Map<String, dynamic>> data, double maxValue, Color lineColor) {
    final interval = _getInterval(data.length);
    return LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipRoundedRadius: 12,
          tooltipPadding: const EdgeInsets.all(12),
          tooltipBorder: BorderSide(color: lineColor.withOpacity(0.3), width: 1),
          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
            return touchedBarSpots.map((barSpot) {
              final index = barSpot.x.toInt().clamp(0, data.length - 1);
              final item = data[index];
              final value = _toDouble(item[_selectedMetric]);
              final unit = _getMetricUnit(_selectedMetric);
              final label = item['displayLabel'] ?? '';
              return LineTooltipItem(
                '${value.toStringAsFixed(2)} $unit\n$label',
                TextStyle(
                  color: lineColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }).toList();
          },
        ),
        handleBuiltInTouches: true,
      ),
      minX: 0,
      maxX: data.length.toDouble() - 1,
      minY: 0,
      maxY: maxValue,
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: interval.toDouble(),
            getTitlesWidget: (value, meta) {
              if (value.toInt() % interval == 0 && value.toInt() < data.length) {
                final index = value.toInt();
                final item = data[index];
                final label = item['displayLabel'] ?? '';

                // Adaptive font size based on screen width
                final screenWidth = MediaQuery.of(context).size.width;
                double fontSize;

                if (screenWidth < 360) {
                  fontSize = 6.0; // Very small screens
                } else if (screenWidth < 480) {
                  fontSize = 7.0; // Small screens
                } else if (screenWidth < 600) {
                  fontSize = 8.0; // Medium screens
                } else {
                  fontSize = 9.0; // Large screens
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _primaryColor.withOpacity(0.8),
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }
              return Container();
            },
          ),
        ),

        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: _calculateAxisInterval(maxValue),
            reservedSize: 50,
            getTitlesWidget: (value, meta) {
              // Adaptive font size for Y-axis labels too
              final screenWidth = MediaQuery.of(context).size.width;
              double fontSize;

              if (screenWidth < 360) {
                fontSize = 8.0;
              } else if (screenWidth < 480) {
                fontSize = 9.0;
              } else if (screenWidth < 600) {
                fontSize = 10.0;
              } else {
                fontSize = 11.0;
              }

              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1),
                  style: TextStyle(
                    color: _primaryColor.withOpacity(0.8),
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            },
          ),
        ),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: BorderSide(color: _primaryColor.withOpacity(0.3), width: 1),
          left: BorderSide(color: _primaryColor.withOpacity(0.3), width: 1),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        drawHorizontalLine: true,
        horizontalInterval: _calculateAxisInterval(maxValue),
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: _primaryColor.withOpacity(0.1),
            strokeWidth: 1,
            dashArray: [5, 5],
          );
        },
      ),
      lineBarsData: [
        // Existing LineChartBarData for actual energy
        LineChartBarData(
          spots: data.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final value = _toDouble(item[_selectedMetric]);
            return FlSpot(index.toDouble(), value * _animation.value);
          }).toList(),
          isCurved: true,
          color: Colors.blue,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),

        // ADD THIS NEW LineChartBarData for AI savings:
        if (_showEnergySavings && _selectedMetric == 'energy')
          LineChartBarData(
            spots: data.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final actualValue = _toDouble(item[_selectedMetric]);
              // Use the new _getPredictedEnergyValue for predicted data
              final predicted = _getPredictedEnergyValue(item, actualValue);
              return FlSpot(index.toDouble(), predicted * _animation.value);
            }).toList(),
            isCurved: true,
            color: Colors.orange,
            barWidth: 2,
            isStrokeCapRound: true,
            dashArray: [5, 5], // Dashed line for predictions
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.orange.withOpacity(0.2),
                  Colors.orange.withOpacity(0.05),
                ],
              ),
            ),
          ),
      ],
    );
  }

  double _getMaxValue(List<Map<String, dynamic>> data, String metric) {
    if (data.isEmpty) return 10;
    final values = data.map((d) => _toDouble(d[metric])).toList();

    // If showing energy savings, also consider predicted values
    if (_showEnergySavings && metric == 'energy') {
      final predictedValues = data.map((item) {
        final actualValue = _toDouble(item[metric]);
        return _getPredictedEnergyValue(item, actualValue);
      }).toList();

      // Combine actual and predicted values to find the true maximum
      final allValues = [...values, ...predictedValues];
      final max = allValues.reduce((a, b) => a > b ? a : b);

      // Cap the maximum at a reasonable value to prevent extreme scaling
      final cappedMax = max > (values.reduce((a, b) => a > b ? a : b) * 3)
          ? values.reduce((a, b) => a > b ? a : b) * 2
          : max;

      return (cappedMax * 1.2).ceilToDouble();
    }

    final max = values.reduce((a, b) => a > b ? a : b);
    return (max * 1.2).ceilToDouble(); // Add 20% padding and round up
  }

  int _getInterval(int length) {
    if (length <= 6) return 1;
    if (length <= 15) return 2;
    if (length <= 24) return 4;
    return (length ~/ 6).clamp(1, length);
  }

  double _calculateAxisInterval(double maxValue) {
    if (maxValue <= 5) return 1;
    if (maxValue <= 10) return 2;
    if (maxValue <= 20) return 4;
    if (maxValue <= 50) return 10;
    return (maxValue / 5).ceilToDouble();
  }

  // MODIFIED: _getPredictedEnergyValue to use aggregated data based on filter
  // FIXED: _getPredictedEnergyValue with consistent 12% maximum savings
  double _getPredictedEnergyValue(Map<String, dynamic> actualDataItem, double actualValue) {
    // Calculate the theoretical maximum predicted energy (12% savings means predicted is actualValue / 0.88)
    final double maxPredictedEnergy = actualValue / 0.88; // This gives exactly 12% savings

    // Default fallback: assume 5% savings if no prediction data found
    double predictedValue = actualValue / 0.95; // 5% savings default

    // Debug logging
    print('=== PREDICTION DEBUG ===');
    print('Actual: $actualValue');
    print('Max allowed predicted (12% savings): $maxPredictedEnergy');

    switch (widget.currentFilter) {
      case 'today':
        final String actualDate = actualDataItem['date'];
        final String actualTimeRange = actualDataItem['timeRange'];

        try {
          final DateTime parsedActualDateTime = DateFormat('EEE MMM dd yyyy HH:mm').parse('$actualDate $actualTimeRange');
          final String lookupKey = DateFormat('yyyy-MM-dd HH:mm').format(parsedActualDateTime);

          print('Today lookup key: $lookupKey');

          if (_aggregatedPredicted30MinEnergy.containsKey(lookupKey)) {
            final double rawPredicted = _aggregatedPredicted30MinEnergy[lookupKey]!;
            print('Raw predicted from DB: $rawPredicted');

            // Cap the predicted value to ensure maximum 12% savings
            predictedValue = math.min(rawPredicted, maxPredictedEnergy);
          }
        } catch (e) {
          print('Error in today prediction lookup: $e');
        }
        break;

      case 'week':
      case 'month':
        final String actualDate = actualDataItem['date'];
        print('Week/Month lookup key: $actualDate');

        if (_aggregatedPredictedDailyEnergy.containsKey(actualDate)) {
          final double rawPredicted = _aggregatedPredictedDailyEnergy[actualDate]!;
          print('Raw predicted from DB: $rawPredicted');

          // Cap the predicted value to ensure maximum 12% savings
          predictedValue = math.min(rawPredicted, maxPredictedEnergy);
        }
        break;

      case 'year':
        final DateTime actualMonthStart = actualDataItem['month'] as DateTime;
        final String monthlyKey = DateFormat('MMM yyyy').format(actualMonthStart);
        print('Year lookup key: $monthlyKey');

        if (_aggregatedPredictedMonthlyEnergy.containsKey(monthlyKey)) {
          final double rawPredicted = _aggregatedPredictedMonthlyEnergy[monthlyKey]!;
          print('Raw predicted from DB: $rawPredicted');

          // Cap the predicted value to ensure maximum 12% savings
          predictedValue = math.min(rawPredicted, maxPredictedEnergy);
        }
        break;
    }

    // Final safety checks

    // 1. Ensure predicted is never less than actual (no negative savings)
    if (predictedValue < actualValue) {
      predictedValue = actualValue; // 0% savings
      print('⚠️ Predicted was less than actual. Set to 0% savings.');
    }

    // 2. Double-check that savings don't exceed 12%
    final double actualSavingsPercent = ((predictedValue - actualValue) / predictedValue) * 100;
    if (actualSavingsPercent > 12.0) {
      predictedValue = actualValue / 0.88; // Force exactly 12% savings
      print('⚠️ Savings exceeded 12%. Capped to exactly 12%.');
    }

    final double finalSavingsPercent = ((predictedValue - actualValue) / predictedValue) * 100;
    print('Final predicted: $predictedValue');
    print('Final savings: ${(predictedValue - actualValue).toStringAsFixed(2)} kWh (${finalSavingsPercent.toStringAsFixed(1)}%)');
    print('========================');

    return predictedValue;
  }

// Also update your _calculateEnergySavings method to handle edge cases better:
  Map<String, double> _calculateEnergySavings() {
    if (_selectedMetric != 'energy' || !_showEnergySavings) {
      return {'totalSavings': 0.0, 'percentageSavings': 0.0};
    }

    double totalActual = 0;
    double totalPredicted = 0;

    final data = _getAggregatedReadings();
    for (var item in data) {
      final actual = _toDouble(item['energy']);
      final predicted = _getPredictedEnergyValue(item, actual);

      totalActual += actual;
      totalPredicted += predicted;
    }

    // Handle edge cases
    if (totalPredicted == 0 || totalPredicted <= totalActual) {
      return {'totalSavings': 0.0, 'percentageSavings': 0.0};
    }

    final savings = totalPredicted - totalActual;
    final percentage = (savings / totalPredicted) * 100;

    // Cap percentage at 12% just in case
    final cappedPercentage = math.min(percentage, 12.0);

    return {
      'totalSavings': savings,
      'percentageSavings': cappedPercentage,
    };
  }

}


extension on Iterable<double> {
  double get average => isEmpty ? 0 : reduce((a, b) => a + b) / length;
}