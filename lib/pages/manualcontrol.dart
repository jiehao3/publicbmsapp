import 'package:flutter/material.dart';
import '../services/mongodb.dart';
import 'animations/animated_feedback.dart';
import '../services/notification_service.dart' as notif;

class ManualControlTab extends StatefulWidget {
  final String building;
  const ManualControlTab({Key? key, required this.building}) : super(key: key);

  @override
  State<ManualControlTab> createState() => _ManualControlTabState();
}

class _ManualControlTabState extends State<ManualControlTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = false;
  bool isLoadingSettings = false;
  Map<String, dynamic>? airconStatus;
  final notif.NotificationService _notificationService = notif.NotificationService();

  // Enhanced color scheme
  final Color primaryBlue = const Color(0xFF2563EB);
  final Color darkBlue = const Color(0xFF1E40AF);
  final Color lightBlue = const Color(0xFFEFF6FF);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color textDark = const Color(0xFF1F2937);
  final Color textLight = const Color(0xFF6B7280);
  final Color white = Colors.white;
  final Color surfaceColor = const Color(0xFFF8FAFC);
  final Color borderColor = const Color(0xFFE2E8F0);

  final List<Map<String, String>> daysOfWeek = [
    {'id': 'monday', 'label': 'Mon'},
    {'id': 'tuesday', 'label': 'Tue'},
    {'id': 'wednesday', 'label': 'Wed'},
    {'id': 'thursday', 'label': 'Thu'},
    {'id': 'friday', 'label': 'Fri'},
    {'id': 'saturday', 'label': 'Sat'},
    {'id': 'sunday', 'label': 'Sun'},
  ];

  String activeDay = 'monday';
  bool smartTemperatureEnabled = true;
  RangeValues temperatureRange = const RangeValues(18, 26);
  double desiredTemperature = 22;
  Map<String, Map<String, dynamic>> settings = {};
  bool _isFCExpanded = false;
  bool _isLightsExpanded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAirconStatus();
    _loadSettings();

    // Initialize default settings
    for (var day in daysOfWeek) {
      settings[day['id']!] = {
        'preCoolingEnabled': day['id'] == 'monday' || day['id'] == 'tuesday',
        'preCoolingTime': 7.0,
        'autoSwitchOffEnabled': day['id'] != 'sunday',
      };
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAirconStatus() async {
    setState(() => isLoading = true);
    try {
      final status = await MongoService.fetchLatestAirconStatus(widget.building);
      if (mounted) {
        setState(() {
          airconStatus = status;
          isLoading = false;
        });
      }
      if (status != null) {
        // Check if any FC unit is ON
        status.forEach((key, value) {
          if (key.startsWith('FC') && value['Status'] == 'ON') {
            _isFCExpanded = true;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }

  }

  Future<void> _loadSettings() async {
    setState(() => isLoadingSettings = true);
    String floorPlanId = '6747dd49c8a6a398ccff24e0'; // Default
    if (widget.building == 'SPGG') {
      floorPlanId = '6784bbcadda3390a2523b23a';
    } else if (widget.building == 'W512') {
      floorPlanId = '6747dd49c8a6a398ccff24e0';
    }
    try {
      final loadedSettings = await MongoService.getSettings(floorPlanId);

      if (mounted) {
        setState(() {
          // Update smart temperature control settings
          smartTemperatureEnabled = loadedSettings['smart_temp_control'] ?? true;
          temperatureRange = RangeValues(
            loadedSettings['min_temp']?.toDouble() ?? 18.0,
            loadedSettings['max_temp']?.toDouble() ?? 26.0,
          );
          desiredTemperature = loadedSettings['desired_temp']?.toDouble() ?? 22.0;
          desiredTemperature = desiredTemperature.clamp(temperatureRange.start, temperatureRange.end);

          // Update daily settings
          final dailySettings = loadedSettings['daily_settings'] as Map<String, dynamic>? ?? {};
          for (var day in daysOfWeek) {
            final dayId = day['id']!;
            final dayData = dailySettings[dayId] as Map<String, dynamic>? ?? {};

            settings[dayId] = {
              'preCoolingEnabled': dayData['preCoolingEnabled'] ?? false,
              'preCoolingTime': dayData['preCoolingTime']?.toDouble() ?? 7.0,
              'autoSwitchOffEnabled': dayData['autoSwitchOffEnabled'] ?? false,
            };
          }

          isLoadingSettings = false;
        });
      }
    } catch (e) {
      print('Error loading settings: $e');
      if (mounted) {
        setState(() {
          isLoadingSettings = false;
        });

        // Show error message
        _notificationService.showNotification(
          context,
          'Failed to load settings',
          type: notif.NotificationType.error,
        );
      }
    }
  }

  Future<void> _saveScheduleSettings() async {
    setState(() => isLoading = true);

    try {
      // Format settings to match website's structure
      final settingsPayload = {
        'settings': {
          'smartTempControl': smartTemperatureEnabled,
          'setPointTempRange': {
            'min': temperatureRange.start,
            'max': temperatureRange.end,
          },
          'desiredRoomTemp': desiredTemperature,
          'dailySettings': {
            for (var day in daysOfWeek)
              day['id']: {
                'preCoolingEnabled': settings[day['id']]!['preCoolingEnabled'],
                'preCoolingTime': settings[day['id']]!['preCoolingTime'],
                'autoSwitchOffEnabled': settings[day['id']]!['autoSwitchOffEnabled'],
              }
          }
        }
      };
      // Use dynamic floorPlanId based on building
      String floorPlanId = '6747dd49c8a6a398ccff24e0'; // Default
      if (widget.building == 'SPGG') {
        floorPlanId = '6784bbcadda3390a2523b23a';
      } else if (widget.building == 'W512') {
        floorPlanId = '6747dd49c8a6a398ccff24e0';
      }
      // Call MongoDB service to save settings
      await MongoService.saveSettings(
          floorPlanId, // floorPlanId - should be dynamic if needed
          settingsPayload
      );

      setState(() => isLoading = false);

      // Show success message
      AnimatedFeedback.showSuccess(context);
    } catch (e) {
      setState(() => isLoading = false);
      // Show error message
      AnimatedFeedback.showError(context);
    }
  }

  String _formatTimeOfDay(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    final period = h >= 12 ? 'PM' : 'AM';
    final displayHour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final minuteStr = m.toString().padLeft(2, '0');
    return '$displayHour:$minuteStr $period';
  }

  void saveSettings() {
    _saveScheduleSettings();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      height: MediaQuery.of(context).size.height - 100,
      child: Column(
        children: [
          // Enhanced Tab Bar
          Container(
            height: 50,
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15), // Increased opacity
                  blurRadius: 16,                        // Increased blur
                  spreadRadius: 0.5,                     // Optional
                  offset: const Offset(0, 6),            // Deeper drop
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: white,
                unselectedLabelColor: textLight,
                indicator: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryBlue, accentBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                dividerColor: Colors.transparent,
                tabs: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.ac_unit_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text('Control'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text('Schedule'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (isLoading || isLoadingSettings)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15), // Increased opacity
                            blurRadius: 16,                        // Increased blur
                            spreadRadius: 0.5,                     // Optional
                            offset: const Offset(0, 6),            // Deeper drop
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading...',
                            style: TextStyle(
                              color: textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: [
                  _buildACControlTab(bottomPadding),
                  _buildScheduleTab(bottomPadding),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab(double bottomPadding) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding + 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          const SizedBox(height: 20),
          _buildSmartTemperatureSection(),
          const SizedBox(height: 20),
          _buildDailyScheduleSection(),
          const SizedBox(height: 24),
          Center(child: _buildSaveButton()),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildACControlTab(double bottomPadding) {
    if (airconStatus == null || airconStatus!.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                spreadRadius: 0.5,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: lightBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.ac_unit_rounded, size: 48, color: primaryBlue),
              ),
              const SizedBox(height: 24),
              Text(
                'No Units Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection and try refreshing',
                style: TextStyle(
                  fontSize: 14,
                  color: textLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadAirconStatus,
                icon: Icon(Icons.refresh_rounded),
                label: Text('Refresh Units'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Separate FC Units and Lights
    final fcUnits = <MapEntry<String, dynamic>>[];
    final lights = <MapEntry<String, dynamic>>[];

    airconStatus!.forEach((key, value) {
      if (key.startsWith('FC')) {
        fcUnits.add(MapEntry(key, value));
      } else if (key.startsWith('Light')) {
        lights.add(MapEntry(key, value));
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(10, 0, 10,  bottomPadding + 24),
          child: Column(
            children: [
              // FC Units Section
              if (fcUnits.isNotEmpty) ...[
                _buildCategoryHeader(
                  title: "FC Units",
                  icon: Icons.ac_unit_rounded,
                  isExpanded: _isFCExpanded,
                  onTap: () => setState(() => _isFCExpanded = !_isFCExpanded),
                ),
                if (_isFCExpanded) const SizedBox(height: 16),
                if (_isFCExpanded)

                  _buildUnitGrid(fcUnits),
              ],

              // Lights Section
              if (lights.isNotEmpty) ...[
                SizedBox(height: 16),
                _buildCategoryHeader(
                  title: "Lights",
                  icon: Icons.lightbulb_outline_rounded,
                  isExpanded: _isLightsExpanded,
                  onTap: () => setState(() => _isLightsExpanded = !_isLightsExpanded),
                ),
                if (_isLightsExpanded) const SizedBox(height: 16),
                if (_isLightsExpanded)
                  _buildUnitGrid(lights),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryHeader({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isExpanded ? primaryBlue : lightBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isExpanded ? white : primaryBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textDark,
              ),
            ),
            const Spacer(),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: textLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitGrid(List<MapEntry<String, dynamic>> entries) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // Always 2 columns
        childAspectRatio: 1.03, // Increased aspect ratio to prevent overflow
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final unitKey = entry.key;
        final unitData = entry.value;
        final String status = unitData['Status'] ?? 'OFF';
        final bool isOn = status == 'ON';
        final double setPoint = (unitData['Set_Point'] ?? 24.0).toDouble();
        final String fanStatus = unitData['Fan_Status']?.isNotEmpty == true
            ? unitData['Fan_Status']
            : 'MID'; // Default to MID if empty

        return GestureDetector(
          onTap: isOn
              ? () => _showUnitSettingsBottomSheet(
            context,
            unitKey,
            unitData,
            isOn,
            setPoint,
            fanStatus,
          )
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOn ? primaryBlue.withOpacity(0.3) : borderColor,
                width: isOn ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 16,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start, // Changed from spaceBetween
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Unit Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: isOn
                              ? LinearGradient(
                            colors: [primaryBlue, accentBlue],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                              : null,
                          color: isOn ? null : lightBlue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          unitKey.startsWith('Light')
                              ? Icons.lightbulb_outline_rounded
                              : Icons.ac_unit_rounded,
                          color: isOn ? white : primaryBlue,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          unitKey.replaceAll('_', ' '),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Status and switch in a row - now positioned right after header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Status indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOn ? lightBlue : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isOn ? 'ACTIVE' : 'INACTIVE',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: isOn ? Colors.lightGreen : textLight,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      // Power switch
                      SizedBox(
                        width: 60, // Explicit width constraint
                        child: Transform.scale(
                          scale: 0.8,
                          child: Switch(
                            value: isOn,
                            activeColor: primaryBlue,
                            activeTrackColor: accentBlue.withOpacity(0.3),
                            inactiveThumbColor: Colors.grey,
                            inactiveTrackColor: Colors.grey.withOpacity(0.3),
                            onChanged: (value) async {
                              setState(() {
                                unitData['Status'] = value ? 'ON' : 'OFF';
                              });
                              if (value) {
                                var setPoint = unitData['Set_Point'];
                                if (setPoint == null || (setPoint is num && setPoint.isNaN)) {
                                  setPoint = 24.0;
                                } else if (setPoint is int) {
                                  setPoint = setPoint.toDouble();
                                } else if (setPoint is! double && setPoint is! int) {
                                  setPoint = 24.0;
                                }
                                final fanMode = unitData['Fan_Status'] ?? 'MID';
                                final double safeTemp = setPoint as double;
                                await MongoService.turnOnAircon(
                                  buildingName: widget.building,
                                  slaveId: unitKey,
                                  temperature: safeTemp,
                                  fanMode: fanMode,
                                );
                              } else {
                                await MongoService.updateAirconPower(widget.building, unitKey, false);
                              }
                              _notificationService.showNotification(
                                context,
                                '${unitKey.startsWith('Light') ? 'Light' : 'AC'} $unitKey ${value ? 'turned on' : 'turned off'}',
                                type: notif.NotificationType.success,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Current settings
                  if (isOn && !unitKey.startsWith('Light')) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.thermostat_rounded,
                          color: primaryBlue,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${setPoint.toStringAsFixed(1)}\u00B0C',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.air_rounded,
                          color: primaryBlue,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          fanStatus,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showUnitSettingsBottomSheet(
      BuildContext context,
      String unitKey,
      Map<String, dynamic> unitData,
      bool isOn,
      double setPoint,
      String fanStatus,
      ) {
    double _currentSetPoint = setPoint; // Local state for slider
    String _currentFanStatus = fanStatus.isNotEmpty ? fanStatus : 'MID';
    final isLight = unitKey.startsWith('Light');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    unitKey.replaceAll('_', ' '),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!isOn)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Unit is currently offline',
                        style: TextStyle(
                          fontSize: 16,
                          color: textLight,
                        ),
                      ),
                    )
                  else
                    ...[
                      if (!isLight) ...[
                        // Temperature Control
                        Row(
                          children: [
                            Icon(
                              Icons.thermostat_rounded,
                              color: primaryBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Temperature',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textDark,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: lightBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_currentSetPoint.toStringAsFixed(1)}\u00B0C',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: darkBlue,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: primaryBlue,
                            inactiveTrackColor: lightBlue,
                            thumbColor: white,
                            overlayColor: primaryBlue.withOpacity(0.2),
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 10),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 20),
                          ),
                          child: Slider(
                            min: 16,
                            max: 32,
                            divisions: 32,
                            value: _currentSetPoint,
                            label: '${_currentSetPoint.toStringAsFixed(1)}\u00B0C',
                            onChanged: isOn
                                ? (value) async {
                              // Update parent state immediately
                              setState(() {
                                airconStatus?[unitKey]?['Set_Point'] = value;
                              });
                              // Update bottom sheet state
                              setState(() {
                                _currentSetPoint = value;
                              });
                              await MongoService.updateAirconSetting(

                                  widget.building, unitKey, 'temp', value: value
                              );
                            }
                                : null,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Fan Speed Control
                        Row(
                          children: [
                            Icon(
                              Icons.air_rounded,
                              color: primaryBlue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Fan Speed',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textDark,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: lightBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _currentFanStatus,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: darkBlue,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildFanSpeedSlider(
                          unitData,
                          _currentFanStatus,
                          isOn,
                          unitKey,
                              (newFanSpeed) {
                            setState(() {
                              _currentFanStatus = newFanSpeed;
                            });

                          },
                        ),
                      ],
                    ],
                  const SizedBox(height: 30),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFanSpeedSlider(
      Map<String, dynamic> unitData,
      String currentSpeed,
      bool isEnabled,
      String unitKey,
      Function(String) onFanSpeedChanged,
      ) {
    // Fan speed mapping
    final Map<String, int> fanMap = {
      'AUTO': 0,
      'VERY LOW': 1,
      'LOW': 2,
      'MID': 3,
      'HIGH': 4,
      'VERY HIGH': 5,
    };

    final Map<int, String> reverseFanMap = {
      0: 'AUTO',
      1: 'VERY LOW',
      2: 'LOW',
      3: 'MID',
      4: 'HIGH',
      5: 'VERY HIGH',
    };

    double currentValue = fanMap[currentSpeed]?.toDouble() ?? 3.0;

    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: isEnabled ? primaryBlue : textLight,
        inactiveTrackColor: isEnabled ? lightBlue : Colors.grey.shade200,
        thumbColor: white,
        overlayColor: primaryBlue.withOpacity(0.2),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        showValueIndicator: ShowValueIndicator.never,
        trackHeight: 4,
      ),
      child: Slider(
        min: 0,
        max: 5,
        divisions: 5,
        value: currentValue,
        label: reverseFanMap[currentValue.round()],
        onChanged: isEnabled
            ? (value) async {
          final int intValue = value.round();
          final String newFanSpeed = reverseFanMap[intValue] ?? 'MID';

          // Update parent state immediately
          setState(() {
            airconStatus?[unitKey]?['Fan_Status'] = newFanSpeed;
          });
          // Update bottom sheet state
          onFanSpeedChanged(newFanSpeed);

          await MongoService.updateAirconSetting(
            widget.building,    // buildingName
            unitKey,            // slaveId
            'fanmode',          // action
            value: intValue,    // optional named parameter
          );
        }
            : null,
      ),
    );
  }

  Widget _buildFanSpeedButton(
      Map<String, dynamic> unitData,
      String speed,
      String currentSpeed,
      bool isEnabled,
      String unitKey,
      ) {
    final bool isSelected = currentSpeed == speed;

    // Fan speed mapping (matches Python backend)
    final Map<String, int> fanMap = {
      'AUTO': 0,
      'VERY LOW': 1,
      'LOW': 2,
      'MID': 3,
      'HIGH': 4,
      'VERY HIGH': 5,
    };

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ElevatedButton(
        onPressed: isEnabled
            ? () async {
          setState(() {
            unitData['Fan_Status'] = speed;
          });

          // Send numeric fan speed (not string)
          await MongoService.updateAirconSetting(
            widget.building,
            unitKey,
            'fanmode',
            value: fanMap[speed] ?? 3, // Default to MID if not found
          );
        }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? primaryBlue : white,
          foregroundColor: isSelected ? white : primaryBlue,
          disabledBackgroundColor: Colors.grey.shade200,
          disabledForegroundColor: Colors.grey.shade400,
          elevation: isSelected ? 4 : 0,
          side: isSelected ? null : BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          speed,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildSmartTemperatureSection() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15), // Increased opacity
          blurRadius: 16,                        // Increased blur
          spreadRadius: 0.5,                     // Optional
          offset: const Offset(0, 6),            // Deeper drop
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primaryBlue, accentBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.thermostat_rounded, color: white, size: MediaQuery.of(context).size.width < 600 ? 14 : 16,),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Control',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width < 600 ? 11 : 16, // Responsive font size
                      fontWeight: FontWeight.w700,
                      color: textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                ],
              ),
            ),
            Transform.scale(
              scale: MediaQuery.of(context).size.width < 600 ? 0.6 : 1.1, // Smaller switch on small screens
              child: Switch(
                value: smartTemperatureEnabled,
                activeColor: primaryBlue,
                activeTrackColor: accentBlue.withOpacity(0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withOpacity(0.3),
                onChanged: (value) {
                  setState(() {
                    smartTemperatureEnabled = value;
                  });
                },
              ),
            ),
          ],
        ),
        if (smartTemperatureEnabled) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Desired Temperature
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: primaryBlue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Desired Temp',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textDark,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: lightBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${desiredTemperature.toStringAsFixed(1)}°C',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: darkBlue,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: primaryBlue,
                    inactiveTrackColor: lightBlue,
                    thumbColor: white,
                    overlayColor: primaryBlue.withOpacity(0.2),
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                  ),
                  child: Slider(
                    min: temperatureRange.start,
                    max: temperatureRange.end,
                    divisions: ((temperatureRange.end - temperatureRange.start) * 2).round(),
                    value: desiredTemperature,
                    label: '${desiredTemperature.toStringAsFixed(1)}°C',
                    onChanged: (value) {
                      setState(() {
                        desiredTemperature = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Temperature Range
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: primaryBlue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Range',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textDark,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: lightBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${temperatureRange.start.toStringAsFixed(1)}°C - ${temperatureRange.end.toStringAsFixed(1)}°C',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: darkBlue,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RangeSlider(
                  min: 16,
                  max: 32,
                  divisions: 32,
                  values: temperatureRange,
                  labels: RangeLabels(
                    '${temperatureRange.start.toStringAsFixed(1)}°C',
                    '${temperatureRange.end.toStringAsFixed(1)}°C',
                  ),
                  activeColor: primaryBlue,
                  inactiveColor: lightBlue,
                  onChanged: (values) {
                    // Add minimum distance constraint (2 degrees in this case)
                    const minDistance = 2.0;
                    if ((values.end - values.start).abs() >= minDistance) {
                      setState(() {
                        temperatureRange = values;
                        // Ensure desired temperature is within range
                        desiredTemperature = desiredTemperature.clamp(values.start, values.end);
                      });
                    } else {
                      // If the distance is too small, adjust the values to maintain minimum distance
                      if (values.start == temperatureRange.start) {
                        // Moving the end thumb
                        setState(() {
                          temperatureRange = RangeValues(values.start, values.start + minDistance);
                          desiredTemperature = desiredTemperature.clamp(values.start, values.start + minDistance);
                        });
                      } else {
                        // Moving the start thumb
                        setState(() {
                          temperatureRange = RangeValues(values.end - minDistance, values.end);
                          desiredTemperature = desiredTemperature.clamp(values.end - minDistance, values.end);
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildDailyScheduleSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15), // Increased opacity
            blurRadius: 16,                        // Increased blur
            spreadRadius: 0.5,                     // Optional
            offset: const Offset(0, 6),            // Deeper drop
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryBlue, accentBlue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.calendar_today_rounded, color: white, size: MediaQuery.of(context).size.width < 600 ? 14 : 16), // Responsive font size),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Schedule',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width < 600 ? 14 : 16, // Responsive font size
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure settings for each day',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width < 600 ? 11 : 13,
                        color: textLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Day Selection
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: daysOfWeek.map((day) {
                  final isActive = activeDay == day['id'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        activeDay = day['id']!;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width < 600 ? 12 : 16, // Responsive padding
                        vertical: MediaQuery.of(context).size.width < 600 ? 8 : 12,    // Responsive padding
                      ),


                      decoration: BoxDecoration(
                        color: isActive ? primaryBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isActive
                            ? [
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                            : null,
                      ),
                      child: Text(
                        day['label']!,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isActive ? white : textLight,
                          fontSize: MediaQuery.of(context).size.width < 600 ? 12 : 14, // Responsive font size
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Day Settings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Pre-cooling Setting
                _buildDaySettingTile(
                  icon: Icons.ac_unit_rounded,
                  title: 'Pre-cooling',
                  value: settings[activeDay]!['preCoolingEnabled'],
                  onChanged: (value) {
                    setState(() {
                      settings[activeDay]!['preCoolingEnabled'] = value;
                    });
                  },
                ),
                if (settings[activeDay]!['preCoolingEnabled']) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, color: primaryBlue, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Pre-cooling:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: textDark,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: lightBlue,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatTimeOfDay(settings[activeDay]!['preCoolingTime']),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: darkBlue,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderThemeData(
                            activeTrackColor: primaryBlue,
                            inactiveTrackColor: lightBlue,
                            thumbColor: white,
                            overlayColor: primaryBlue.withOpacity(0.2),
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                          ),
                          child: Slider(
                            min: 0,
                            max: 23.5,
                            divisions: 47,
                            value: settings[activeDay]!['preCoolingTime'],
                            label: _formatTimeOfDay(settings[activeDay]!['preCoolingTime']),
                            onChanged: (value) {
                              setState(() {
                                settings[activeDay]!['preCoolingTime'] = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Auto Switch Off Setting
                _buildDaySettingTile(
                  icon: Icons.power_settings_new_rounded,
                  title: 'Auto Switch Off',
                  value: settings[activeDay]!['autoSwitchOffEnabled'],
                  onChanged: (value) {
                    setState(() {
                      settings[activeDay]!['autoSwitchOffEnabled'] = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySettingTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? primaryBlue.withOpacity(0.3) : borderColor,
          width: value ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value ? primaryBlue : lightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: value ? white : primaryBlue,
              size: MediaQuery.of(context).size.width < 600 ? 12 : 14,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textDark,
                    fontSize: MediaQuery.of(context).size.width < 600 ? 11 : 20,
                  ),
                ),


              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 0.0),
            child: Transform.scale(
              scale: MediaQuery.of(context).size.width < 600 ? 0.6 : 1.1,
              child: Switch(
                value: value,
                activeColor: primaryBlue,
                activeTrackColor: accentBlue.withOpacity(0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withOpacity(0.3),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 400),
      child: ElevatedButton(
        onPressed: isLoading ? null : saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: white,
          disabledBackgroundColor: Colors.grey.shade300,
          disabledForegroundColor: Colors.grey.shade500,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: primaryBlue.withOpacity(0.3),
        ),
        child: isLoading
            ? Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(white),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Saving...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save_rounded, size: 18),
            const SizedBox(width: 8),
            Text(
              'Save Settings',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}