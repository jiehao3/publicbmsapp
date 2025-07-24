import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class EnergyTab extends StatefulWidget {
  final List<Map<String, dynamic>> sensorData;
  final String currentFilter;
  final String selectedMetric;
  final Function(String) onMetricChanged;

  const EnergyTab({
    super.key,
    required this.sensorData,
    required this.currentFilter,
    required this.selectedMetric,
    required this.onMetricChanged,
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
  final Map<String, Map<String, double>> _dummyPredictionData = {
    // Use today's date as key
    DateFormat('EEE MMM dd yyyy').format(DateTime.now()): {
      // 8:00 AM - 8:30 AM cycle (every 10 minutes)
      '08:00': 1.2,
      '08:10': 1.6,
      '08:20': 1.1,
      '08:30': 1.8,

      // 2:00 PM - 2:30 PM cycle
      '14:00': 2.4,
      '14:10': 2.8,
      '14:20': 2.1,
      '14:30': 2.7,

      // 8:00 PM - 8:30 PM cycle
      '20:00': 1.8,
      '20:10': 1.1,
      '20:20': 2.5,
      '20:30': 2.2,
    },
  };

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
    final targetDate =
    DateFormat('EEE MMM dd yyyy').parse(currentEntries.first['date']);
    final hours = List.generate(24, (hour) {
      final hourStart =
      DateTime(targetDate.year, targetDate.month, targetDate.day, hour);
      return {
        'start': hourStart,
        'end': hourStart.add(const Duration(hours: 1)),
        'entries': <Map<String, dynamic>>[],
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
    return hours
        .where((hourSlot) => (hourSlot['start'] as DateTime).isBefore(DateTime.now()))
        .map((hourSlot) {
      final entries = hourSlot['entries'] as List<Map<String, dynamic>>;
      final hasData = entries.isNotEmpty;
      return {
        'date': DateFormat('EEE MMM dd yyyy')
            .format(hourSlot['start'] as DateTime),
        'timeRange':
        '${DateFormat('HH:mm').format(hourSlot['start'] as DateTime)}',
        'displayLabel':
        DateFormat('HH:mm').format(hourSlot['start'] as DateTime),
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
        'date': formattedDate,
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
      final monthKey = DateFormat('yyyy-MM').format(monthStart);
      final entries = dataByMonth[monthKey] ?? [];
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
        // Existing LineChartBarData stays exactly the same...
        LineChartBarData(
          spots: data.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final value = _toDouble(item[_selectedMetric]);
            return FlSpot(index.toDouble(), value * _animation.value);
          }).toList(),
          isCurved: true,
          color: lineColor,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: data.length <= 24,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: lineColor,
              );
            },
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                lineColor.withOpacity(0.3),
                lineColor.withOpacity(0.05),
              ],
            ),
          ),
        ),

        // ADD THIS NEW LineChartBarData for AI savings:
        if (_showEnergySavings && _selectedMetric == 'energy')
          LineChartBarData(
            spots: data.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final actualValue = _toDouble(item[_selectedMetric]);
              final predictedSavings = _calculatePredictedSavings(index, actualValue);
              return FlSpot(index.toDouble(), predictedSavings * _animation.value);
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
                  Colors.orange.withOpacity(0.2), // Change from green
                  Colors.orange.withOpacity(0.05), // Change from green
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
  double _calculatePredictedSavings(int index, double actualValue) {
    // Only works for hourly (today) data
    if (widget.currentFilter != 'today') {
      return actualValue;
    }

    // Get today's date in the same format as sensor data
    final today = DateFormat('EEE MMM dd yyyy').format(DateTime.now());

    // Check if we have prediction data for today
    if (!_dummyPredictionData.containsKey(today)) {
      return actualValue;
    }

    final todayPredictions = _dummyPredictionData[today]!;
    final timeLabel = '${index.toString().padLeft(2, '0')}:00';

    // Check if we have prediction data for this exact time
    if (todayPredictions.containsKey(timeLabel)) {
      return todayPredictions[timeLabel]!;
    }

    // Check for 10-minute intervals within this hour
    final hour10 = '${index.toString().padLeft(2, '0')}:10';
    final hour20 = '${index.toString().padLeft(2, '0')}:20';
    final hour30 = '${index.toString().padLeft(2, '0')}:30';

    final predictions = [
      todayPredictions[timeLabel],
      todayPredictions[hour10],
      todayPredictions[hour20],
      todayPredictions[hour30],
    ].where((pred) => pred != null).cast<double>().toList();

    if (predictions.isNotEmpty) {
      return predictions.reduce((a, b) => a + b) / predictions.length;
    }

    return actualValue; // No prediction data available
  }
  Map<String, double> _calculateEnergySavings() {
    if (_selectedMetric != 'energy' || !_showEnergySavings) {
      return {'totalSavings': 0.0, 'percentageSavings': 0.0};
    }

    final data = _getAggregatedReadings();
    double totalActual = 0.0;
    double totalPredicted = 0.0;
    int dataPoints = 0;

    for (int i = 0; i < data.length; i++) {
      final actualValue = _toDouble(data[i][_selectedMetric]);
      final predictedValue = _calculatePredictedSavings(i, actualValue);

      if (predictedValue != actualValue) { // Only count where we have prediction data
        totalActual += actualValue;
        totalPredicted += predictedValue;
        dataPoints++;
      }
    }

    if (dataPoints == 0 || totalPredicted == 0) {
      return {'totalSavings': 0.0, 'percentageSavings': 0.0};
    }

    final totalSavings = totalPredicted - totalActual;
    final percentageSavings = (totalSavings / totalPredicted) * 100;

    return {
      'totalSavings': totalSavings,
      'percentageSavings': percentageSavings,
    };
  }
}

extension on Iterable<double> {
  double get average => isEmpty ? 0 : reduce((a, b) => a + b) / length;
}