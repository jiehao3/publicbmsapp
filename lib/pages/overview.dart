import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OverviewTab extends StatefulWidget {
  final List<Map<String, dynamic>> sensorData;
  final double Function() calculateTotalEnergy;
  final double Function() calculateTotalCost;
  final double Function() calculateAvgTemp;
  final double Function() calculateAvgHumidity;
  final int Function() calculateAvgOccupancy;
  final String currentFilter;
  const OverviewTab({
    super.key,
    required this.sensorData,
    required this.calculateTotalEnergy,
    required this.calculateTotalCost,
    required this.calculateAvgTemp,
    required this.calculateAvgHumidity,
    required this.calculateAvgOccupancy,
    required this.currentFilter,
  });

  @override
  State<OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<OverviewTab> {
  final ScrollController _scrollController = ScrollController();

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
    if (value is double) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    return 0;
  }

  Map<String, Object> _calculatePeakEnergyUsage() {
    if (widget.sensorData.isEmpty) {
      return {
        'value': 0.0,
        'period': 'N/A',
      };
    }
    final List<Map<String, dynamic>> aggregatedData = _getAggregatedReadings();
    if (aggregatedData.isEmpty) {
      return {
        'value': 0.0,
        'period': 'N/A',
      };
    }
    Map<String, dynamic> maxEnergyEntry = aggregatedData.first;
    for (var entry in aggregatedData) {
      final entryEnergy = _toDouble(entry['energy']);
      final maxEnergy = _toDouble(maxEnergyEntry['energy']);
      if (entryEnergy > maxEnergy) {
        maxEnergyEntry = entry;
      }
    }
    String periodLabel;
    switch (widget.currentFilter) {
      case 'today':
        periodLabel = maxEnergyEntry['timeRange'];
        break;
      case 'week':
      case 'month':
      case 'year':
        periodLabel = maxEnergyEntry['formattedDate'];
        break;
      default:
        periodLabel = maxEnergyEntry['date'];
    }
    return {
      'value': _toDouble(maxEnergyEntry['energy']),
      'period': periodLabel,
    };
  }

  List<Map<String, dynamic>> _getAggregatedReadings() {
    if (widget.sensorData.isEmpty) return [];
    switch (widget.currentFilter) {
      case 'today':
        return _getHourlyReadings();
      case 'week':
      case 'month':
        return _getDailyReadings();
      case 'year':
        return _getMonthlyReadings();
      default:
        return _getHourlyReadings();
    }
  }

  List<Map<String, dynamic>> _getHourlyReadings() {
    if (widget.sensorData.isEmpty) return [];
    final currentEntries = widget.sensorData.where((entry) {
      final now = DateTime.now();
      final today = DateFormat('EEE MMM dd yyyy').format(now);
      return entry['date'] == today;
    }).toList();
    if (currentEntries.isEmpty) return [];
    final targetDate = DateFormat('EEE MMM dd yyyy').parse(currentEntries.first['date']);
    final hours = List.generate(24, (hour) {
      final hourStart = DateTime(targetDate.year, targetDate.month, targetDate.day, hour);
      return {
        'start': hourStart,
        'end': hourStart.add(const Duration(hours: 1)),
        'entries': <Map<String, dynamic>>[],
        'hour': hour,
      };
    });
    for (var entry in currentEntries) {
      final entryTime = DateFormat('EEE MMM dd yyyy h:mm:ss a')
          .parse('${entry['date']} ${entry['time']}');
      for (var hourSlot in hours) {
        final DateTime start = hourSlot['start'] as DateTime;
        final DateTime end = hourSlot['end'] as DateTime;
        if (entryTime.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
            entryTime.isBefore(end)) {
          (hourSlot['entries'] as List<Map<String, dynamic>>).add(entry);
          break;
        }
      }
    }
    return hours.map((hourSlot) {
      final entries = hourSlot['entries'] as List<Map<String, dynamic>>;
      final hasData = entries.isNotEmpty;
      return {
        'date': DateFormat('EEE MMM dd yyyy').format(hourSlot['start'] as DateTime),
        'timeRange':
        '${DateFormat('ha').format(hourSlot['start'] as DateTime)} - ${DateFormat('ha').format(hourSlot['end'] as DateTime)}',
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
        'hour': hourSlot['hour'],
      };
    }).toList();
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
          (i) => DateTime(startDate.year, startDate.month, startDate.day).add(Duration(days: i)),
    );
    final dailyData = <String, List<Map<String, dynamic>>>{};
    for (final entry in widget.sensorData) {
      try {
        final entryDateString = entry['date'] as String;
        final parsedDate = DateFormat('EEE MMM dd yyyy').parse(entryDateString);
        final normalizedDateString = DateFormat('EEE MMM dd yyyy').format(parsedDate);
        dailyData.putIfAbsent(normalizedDateString, () => []).add(entry);
      } catch (e) {
        print('⚠️ Error processing entry: $e');
      }
    }
    return dateRange.map((date) {
      final formattedDate = DateFormat('EEE MMM dd yyyy').format(date);
      final entries = dailyData[formattedDate] ?? [];
      return {
        'date': formattedDate,
        'formattedDate': DateFormat('MMM d').format(date),
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
      final entryDate = DateFormat('EEE MMM dd yyyy').parse(entry['date'] as String);
      final monthKey = DateFormat('yyyy-MM').format(entryDate);
      dataByMonth.putIfAbsent(monthKey, () => []).add(entry);
    }
    DateTime now = DateTime.now();
    List<DateTime> months = [];
    DateTime currentDate = DateTime(now.year, now.month, 1);
    for (int i = 0; i < 12; i++) {
      months.add(currentDate);
      currentDate = DateTime(currentDate.year, currentDate.month - 1, 1);
    }
    months = months.reversed.toList();
    List<Map<String, dynamic>> monthlyData = [];
    for (var monthStart in months) {
      final monthKey = DateFormat('yyyy-MM').format(monthStart);
      final entries = dataByMonth[monthKey] ?? [];
      monthlyData.add({
        'month': monthStart,
        'formattedDate': DateFormat('MMM yyyy').format(monthStart),
        'energy': entries.fold(0.0, (sum, e) => sum + _toDouble(e['energy'])),
        'temperature': entries.isNotEmpty
            ? entries.map((e) => _toDouble(e['temperature'])).average
            : 0.0,
        'humidity': entries.isNotEmpty
            ? entries.map((e) => _toDouble(e['humidity'])).average
            : 0.0,
        'occupancy': entries.fold(0, (sum, e) => sum + _toInt(e['occupancy'])),
      });
    }
    return monthlyData;
  }

  void _scrollToCurrentTime() {
    if (widget.currentFilter != 'today') return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final now = DateTime.now();
      final currentHour = now.hour;

      // Find the index of the current hour
      final aggregatedData = _getAggregatedReadings();
      final currentIndex = aggregatedData.indexWhere((item) => _toInt(item['hour']) == currentHour);

      if (currentIndex == -1) return;

      // Calculate the position to scroll to
      // We'll estimate 60px for header and 56px per item (adjust based on your actual item height)
      final estimatedItemHeight = 56.0;
      final headerHeight = 60.0;
      final targetPosition = (currentIndex * estimatedItemHeight) - (headerHeight / 2);

      // Ensure we don't scroll past the end
      final maxScroll = _scrollController.position.maxScrollExtent;
      final adjustedPosition = targetPosition.clamp(0.0, maxScroll);

      _scrollController.animateTo(
        adjustedPosition,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final peak = _calculatePeakEnergyUsage();
    final double peakValue = _toDouble(peak['value']);
    final String peakPeriod = peak['period'].toString();

    final currentEnergy = widget.calculateTotalEnergy();
    final currentCost = widget.calculateTotalCost();
    final currentTemp = widget.calculateAvgTemp();
    final currentHumidity = widget.calculateAvgHumidity();
    final currentOccupancy = widget.calculateAvgOccupancy();

    // Responsive logic from second function
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = false; // Better device detection

    int getCrossAxisCount() {
      if (screenWidth < 600) return 2;
      if (screenWidth < 900) return 3;
      if (screenWidth < 1200) return 4;
      return 5;
    }

    double getAspectRatio() {
      if (isTablet) {
        return 1.2; // Tablets can handle more content
      } else {
        // Phones need taller cards for readability
        if (screenHeight < 700) return 1.4; // Short screens
        if (screenHeight < 900) return 1.3; // Medium screens
        return 1.2; // Tall screens
      }
    }

    String getDisplayTitle(String filter) {
      switch (filter) {
        case 'today':
          return "Today's";
        case 'week':
          return "This Week's";
        case 'month':
          return "This Month's";
        case 'year':
          return "This Year's";
        case 'all':
          return "All Time";
        default:
          return "${filter[0].toUpperCase()}${filter.substring(1)}'s";
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              "${getDisplayTitle(widget.currentFilter)} Overview",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: getCrossAxisCount(),
            crossAxisSpacing: screenWidth < 600 ? 8 : 12,
            mainAxisSpacing: screenWidth < 600 ? 8 : 12,
            childAspectRatio: getAspectRatio(),
            children: [
              _metricCard(
                icon: Icons.bolt,
                title: 'Total Energy',
                value: '${currentEnergy.toStringAsFixed(2)} kWh',
                iconColor: const Color(0xFF3498DB),
              ),
              _metricCard(
                icon: Icons.payments,
                title: 'Total Cost',
                value: '\$${currentCost.toStringAsFixed(2)}',
                iconColor: const Color(0xFF9B59B6),
              ),
              _metricCard(
                icon: Icons.thermostat,
                title: 'Avg Temperature',
                value: '${currentTemp.toStringAsFixed(1)}°C',
                iconColor: const Color(0xFFE74C3C),
              ),
              _metricCard(
                icon: Icons.water_drop,
                title: 'Avg Humidity',
                value: '${currentHumidity.toStringAsFixed(1)}%',
                iconColor: const Color(0xFF1ABC9C),
              ),
              _metricCard(
                icon: Icons.group,
                title: 'Avg Occupancy',
                value: currentOccupancy.toString(),
                iconColor: const Color(0xFFFF9800),
              ),
              _metricCard(
                icon: Icons.bolt_outlined,
                title: 'Peak Energy Usage',
                value: '$peakPeriod',
                iconColor: const Color(0xFFE67E22),
              ),
            ],
          ),

          const SizedBox(height: 0),
          buildResponsiveCard2(context)
        ],
      ),
    );
  }
  Widget buildResponsiveCard2(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final useCompactButton = availableWidth < 300;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Detailed Readings',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: useCompactButton ? 15 : 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                useCompactButton
                    ? IconButton(
                  onPressed: () => _showDetailedReadingsPopup(),
                  icon: const Icon(Icons.table_chart, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
                    : ElevatedButton.icon(
                  onPressed: () => _showDetailedReadingsPopup(),
                  icon: const Icon(Icons.table_chart, size: 16),
                  label: const Text('View'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }


  void _showDetailedReadingsPopup() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
          ),
          child: Column(
            children: [
              // Fixed header with proper constraints
              Container(
                padding: const EdgeInsets.all(16), // Reduced padding
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    // Use Expanded to prevent overflow
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Detailed Sensor Readings',
                            style: const TextStyle(
                              fontSize: 18, // Slightly smaller
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis, // Handle overflow
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.currentFilter == 'today' ? 'Hourly breakdown' :
                            widget.currentFilter == 'year' ? 'Monthly breakdown' : 'Daily breakdown',
                            style: const TextStyle(
                              fontSize: 13, // Slightly smaller
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis, // Handle overflow
                          ),
                        ],
                      ),
                    ),
                    // Fixed width close button
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: IconButton(
                        onPressed: Navigator.of(context).pop,
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: EdgeInsets.zero, // Remove default padding
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: widget.sensorData.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No sensor data available',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
                    : _buildDetailedReadings(context),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Auto-scroll after dialog opens for today view
      if (widget.currentFilter == 'today') {
        _scrollToCurrentTime();
      }
    });
  }

  Widget _buildDetailedReadings(BuildContext context) {
    final aggregatedData = _getAggregatedReadings();
    final isToday = widget.currentFilter == 'today';
    final isYear = widget.currentFilter == 'year';

    // Auto-scroll for today view
    if (isToday) {
      _scrollToCurrentTime();
    }

    return Container(
      margin: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Header
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 2)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      Icon(
                        isYear ? Icons.calendar_month : (isToday ? Icons.access_time : Icons.calendar_today),
                        size: 16,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isYear ? 'Month' : (isToday ? 'Time' : 'Date'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Icon(
                    Icons.bolt,
                    size: 18,
                    color: Color(0xFF3498DB),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Icon(
                    Icons.thermostat,
                    size: 18,
                    color: Color(0xFFE74C3C),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Icon(
                    Icons.water_drop,
                    size: 18,
                    color: Color(0xFF1ABC9C),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Icon(
                    Icons.group,
                    size: 18,
                    color: Color(0xFFFF9800),
                  ),
                ),
              ],
            ),
          ),
          // Data rows
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: aggregatedData.length,
              itemBuilder: (ctx, i) {
                final item = aggregatedData[i];
                final isCurrentHour = isToday && _toInt(item['hour']) == DateTime.now().hour;

                return Container(
                  decoration: BoxDecoration(
                    color: isCurrentHour ? Colors.blue.shade50 :
                    i.isEven ? Colors.white : Colors.grey.shade100,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                      left: isCurrentHour ? const BorderSide(color: Colors.blue, width: 3) : BorderSide.none,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Row(
                            children: [
                              if (isCurrentHour) ...[
                                const Icon(Icons.access_time, size: 14, color: Colors.blue),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  isYear
                                      ? item['formattedDate'].toString()
                                      : isToday
                                      ? item['timeRange'].toString()
                                      : item['formattedDate'].toString(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCurrentHour ? FontWeight.w600 : FontWeight.normal,
                                    color: isCurrentHour ? Colors.blue.shade800 : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            _toDouble(item['energy']).toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF3498DB),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            _toDouble(item['temperature']).toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFE74C3C),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            _toDouble(item['humidity']).toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1ABC9C),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            _toInt(item['occupancy']).toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFFFF9800),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
    String? subtitle,
  }) {
    // Get screen dimensions for responsive sizing
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    // Calculate responsive font sizes based on screen height
    double getTitleFontSize() {
      if (screenHeight < 600) return 8;      // Very small screens
      if (screenHeight < 800) return 9;      // Small screens
      if (screenHeight < 1000) return 12;     // Medium screens
      if (screenHeight < 1200) return 13;     // Large screens
      return 14;                              // Extra large screens
    }

    double getValueFontSize() {
      if (screenHeight < 600) return 10;      // Very small screens
      if (screenHeight < 800) return 12;      // Small screens
      if (screenHeight < 1000) return 18;     // Medium screens
      if (screenHeight < 1200) return 20;     // Large screens
      return 22;                              // Extra large screens
    }

    double getSubtitleFontSize() {
      if (screenHeight < 600) return 7;       // Very small screens
      if (screenHeight < 800) return 9;       // Small screens
      if (screenHeight < 1000) return 10;     // Medium screens
      if (screenHeight < 1200) return 11;     // Large screens
      return 12;                              // Extra large screens
    }

    double getIconSize() {
      if (screenHeight < 600) return 18;      // Very small screens
      if (screenHeight < 800) return 20;      // Small screens
      if (screenHeight < 1000) return 22;     // Medium screens
      if (screenHeight < 1200) return 24;     // Large screens
      return 26;                              // Extra large screens
    }

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: iconColor.withOpacity(0.2), width: 1.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(screenWidth < 600 ? 4.0 : screenWidth < 900 ? 6.0 : 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: getIconSize(), color: iconColor),
            ),
            SizedBox(height: screenHeight < 600 ? 4 : screenHeight < 800 ? 6 : 8),
            Text(
              title,
              style: TextStyle(
                fontSize: getTitleFontSize(),
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight < 600 ? 2 : 4),
            Text(
              value,
              style: TextStyle(
                fontSize: getValueFontSize(),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: getSubtitleFontSize(),
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

extension on Iterable<double> {
  double get average => isEmpty ? 0 : reduce((a, b) => a + b) / length;
}