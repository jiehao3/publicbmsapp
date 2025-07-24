import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bmsapp/services/mongodb.dart';
import 'animations/animated_feedback.dart';

class SchedulingTab extends StatefulWidget {
  final String building;
  const SchedulingTab({Key? key, required this.building}) : super(key: key);
  @override
  State<SchedulingTab> createState() => _SchedulingTabState();
}

class _SchedulingTabState extends State<SchedulingTab>
    with AutomaticKeepAliveClientMixin {
  late final String _buildingId;
  late final String _floorPlanId;
  String _selectedFilter = 'Today';
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _allEvents = [];
  DateTime _displayedMonth = DateTime.now();
  bool _isDaySelected = true; // Set to true initially to select today's date
  bool _isCalendarView = true; // Add this line



  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    print("Building name received: '${widget.building}'");
    if (widget.building == 'W512') {
      _buildingId = '6747d96ec8a6a398ccff24df';
      _floorPlanId = '6747dd49c8a6a398ccff24e0';
    } else if (widget.building == 'SPGG') {
      _buildingId = '6748234ad62de7b3885daed1';
      _floorPlanId = '6748234ad62de7b3885daed1';
    }
    else if (widget.building == 'Model_1') {
      _buildingId = '686cbf1dd995ddf5380d1c39';
      _floorPlanId = '686cbf83d995ddf5380d1c3b';
    }else {
      _buildingId = '';
      _floorPlanId = '';
    }
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final events = await MongoService.fetchEvents(buildingId: _buildingId);
      setState(() {
        _allEvents = events
            .where((event) => event['floorPlanId'] == _floorPlanId)
            .map((event) {
          return {
            ...event,
            'id': event['_id'] ?? event['id'],
          };
        })
            .toList();
      });
    } catch (e) {
      print('Error loading events: $e');
    }
  }


  List<Map<String, dynamic>> _getEventsForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    return _allEvents.where((e) {
      final eventDate = DateTime.tryParse(e['date'] ?? '');
      if (eventDate == null) return false;
      final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
      return eventDay.isAtSameMomentAs(targetDate);
    }).toList();
  }
  List<String> _generateTimeOptions() {
    final List<String> times = [];
    for (int hour = 0; hour < 24; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        final hourStr = hour.toString().padLeft(2, '0');
        final minuteStr = minute.toString().padLeft(2, '0');
        times.add('$hourStr:$minuteStr');
      }
    }
    return times;
  }

  bool _hasEventsOnDate(DateTime date) {
    return _getEventsForDate(date).isNotEmpty;
  }

  @override
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required when using AutomaticKeepAliveClientMixin

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(13.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Events',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: MediaQuery.of(context).size.width < 350 ? 18 :
                    MediaQuery.of(context).size.width < 400 ? 20 : 23,
                  ),
                ),
                // Add view toggle buttons
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,  // Changed from Colors.grey.shade200
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [  // Add this shadow
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.calendar_month,
                          color: _isCalendarView ? Colors.white : Colors.grey.shade600,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _isCalendarView = true),
                        style: IconButton.styleFrom(
                          backgroundColor: _isCalendarView ? const Color(0xFF2563EB) : Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.list,
                          color: !_isCalendarView ? Colors.white : Colors.grey.shade600,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _isCalendarView = false),
                        style: IconButton.styleFrom(
                          backgroundColor: !_isCalendarView ? const Color(0xFF2563EB) : Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            if (_isCalendarView) ...[
              Container(
                height: MediaQuery.of(context).size.height * 0.35,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                child: _buildCalendar(context),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.025),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MonthSelector(
                    selectedMonth: _displayedMonth,
                    onMonthChanged: (newMonth) {
                      setState(() {
                        _displayedMonth = newMonth;
                        _isDaySelected = false;
                        _selectedDate = DateTime(0);
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (!_isCalendarView) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(child: _buildImprovedFilterButton('Today')),
                    Expanded(child: _buildImprovedFilterButton('Upcoming')),
                    Expanded(child: _buildImprovedFilterButton('Past')),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            _isCalendarView
                ? _buildTodayEventsSection(context)
                : _buildEnhancedListView(context),
          ],
        ),
      ),
    );
  }
  Widget _buildImprovedFilterButton(String filter) {
    final isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isSelected ? Colors.white : Colors.black87,
            ),
            child: Text(filter),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = _displayedMonth; // Changed from DateTime.now()
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final firstDay = DateTime(now.year, now.month, 1);
    final offset = firstDay.weekday % 7;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final currentDate = DateTime.now();
    final displayedMonth = _displayedMonth; // Keep for month/year display

    return Column(
      children: [
        // Weekday header with gradient
        Container(
          height: MediaQuery.of(context).size.height * 0.05,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.1),
                colorScheme.primary.withOpacity(0.05),
              ],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
          ),
          child: Row(
            children: days
                .map((d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: MediaQuery.of(context).size.width < 350 ? 11 :
                    MediaQuery.of(context).size.width < 400 ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ))
                .toList(),
          ),
        ),
        // Calendar grid with enhanced styling
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: offset + daysInMonth,
            itemBuilder: (c, i) {
              if (i < offset) return Container();
              final day = i - offset + 1;
              final currentDate = DateTime(now.year, now.month, day);
              final isToday = currentDate.year == DateTime.now().year &&
                  currentDate.month == DateTime.now().month &&
                  currentDate.day == DateTime.now().day;
              final hasEvents = _hasEventsOnDate(currentDate);
              final isSelected = _isDaySelected &&
                  _selectedDate.day == day &&
                  _selectedDate.month == now.month &&
                  _selectedDate.year == now.year;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = currentDate;
                    _isDaySelected = true;
                  });
                  _showDayEventsDialog(c, currentDate);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withOpacity(0.8),
                      ],
                    )
                        : isToday && _displayedMonth.month == DateTime.now().month
                        ? LinearGradient(
                      colors: [
                        colorScheme.secondary,
                        colorScheme.secondary.withOpacity(0.8),
                      ],
                    )
                        : hasEvents
                        ? LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(0.2),
                        Colors.orange.withOpacity(0.1),
                      ],
                    )
                        : null,
                    borderRadius: BorderRadius.circular(12),
                    border: hasEvents && !isSelected && !isToday
                        ? Border.all(color: Colors.orange, width: 1.5)
                        : null,
                    boxShadow: isSelected || (isToday && _displayedMonth.month == DateTime.now().month)
                        ? [
                      BoxShadow(
                        color: (isSelected
                            ? colorScheme.primary
                            : colorScheme.secondary)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                        : null,
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '$day',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: MediaQuery.of(context).size.width < 350 ? 12 :
                            MediaQuery.of(context).size.width < 400 ? 13 : 14,
                            fontWeight: hasEvents || isToday || isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected || (isToday && _displayedMonth.month == DateTime.now().month)
                                ? Colors.white
                                : hasEvents
                                ? Colors.orange.shade700
                                : colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (hasEvents && !isSelected && !isToday)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange,
                                  Colors.orange.shade600,
                                ],
                              ),
                              shape: BoxShape.circle,
                            ),
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
    );
  }
  Widget _buildTodayEventsSection(BuildContext context) {
    final today = DateTime.now();
    final todayEvents = _allEvents.where((e) {
      final eventDate = DateTime.tryParse(e['date'] ?? '');
      if (eventDate == null) return false;
      final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
      final todayDay = DateTime(today.year, today.month, today.day);
      return eventDay.isAtSameMomentAs(todayDay);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (todayEvents.isEmpty)
            const SizedBox.shrink()
        else
          ...todayEvents.map((event) => Container(
            margin: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
            child: Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        event['finished'] == true ? Icons.check_circle : Icons.schedule,
                        color: event['finished'] == true ? Colors.green : const Color(0xFF2563EB),
                        size: MediaQuery.of(context).size.width < 350 ? 20 :
                        MediaQuery.of(context).size.width < 400 ? 22 : 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event['title'] ?? 'Untitled Event',
                            style: TextStyle(
                              fontSize: MediaQuery.of(context).size.width < 350 ? 14 :
                              MediaQuery.of(context).size.width < 400 ? 15 : 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                  Icons.access_time,
                                  size: MediaQuery.of(context).size.width < 350 ? 14 :
                                  MediaQuery.of(context).size.width < 400 ? 15 : 16,
                                  color: Colors.grey.shade600
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${event['startTime']} - ${event['endTime']}',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: MediaQuery.of(context).size.width < 350 ? 12 :
                                    MediaQuery.of(context).size.width < 400 ? 13 : 14
                                ),
                              ),
                              const SizedBox(width: 16),
                              Icon(
                                  Icons.thermostat,
                                  size: MediaQuery.of(context).size.width < 350 ? 14 :
                                  MediaQuery.of(context).size.width < 400 ? 15 : 16,
                                  color: Colors.grey.shade600
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${event['temp']}°C',
                                style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: MediaQuery.of(context).size.width < 350 ? 12 :
                                    MediaQuery.of(context).size.width < 400 ? 13 : 14
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (event['finished'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Completed',
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width < 350 ? 10 :
                            MediaQuery.of(context).size.width < 400 ? 11 : 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )).toList(),
      ],
    );
  }

  void _showDayEventsDialog(BuildContext context, DateTime date) {
    final eventsForDay = _getEventsForDate(date);
    final formattedDate = DateFormat('EEEE, MMM dd, yyyy').format(date);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Events for $formattedDate',
          style: TextStyle(
            fontSize: MediaQuery.of(context).size.width < 350 ? 16 :
            MediaQuery.of(context).size.width < 400 ? 17 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 1.5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eventsForDay.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(0),
                  child: Text(
                    'No events scheduled for this day',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width < 350 ? 12 :
                      MediaQuery.of(context).size.width < 400 ? 13 : 14,
                    ),
                  ),
                )
              else
                ...eventsForDay.map((event) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.event, color: Colors.blue),
                    title: Text(
                      event['title'] ?? 'Untitled Event',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width < 350 ? 12 :
                        MediaQuery.of(context).size.width < 400 ? 13 : 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      '${event['startTime']} - ${event['endTime']}\nTemp: ${event['temp']}°C',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width < 350 ? 10 :
                        MediaQuery.of(context).size.width < 400 ? 11 : 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          event['finished'] == true
                              ? Icons.check_circle
                              : Icons.schedule,
                          color: event['finished'] == true
                              ? Colors.green
                              : Colors.orange,
                          size: MediaQuery.of(context).size.width < 350 ? 18 : 20,
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Colors.red,
                            size: MediaQuery.of(context).size.width < 350 ? 18 : 20,
                          ),
                          onPressed: () =>
                              _showDeleteConfirmationDialog(
                                  context, event, fromCalendarDialog: true),
                        ),
                      ],
                    ),
                  ),
                )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 350 ? 12 :
                MediaQuery.of(context).size.width < 400 ? 13 : 14,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showAddEventDialog(context, date);
            },
            icon: Icon(
              Icons.add,
              size: MediaQuery.of(context).size.width < 350 ? 16 : 18,
            ),
            label: Text(
              'Add Event',
              style: TextStyle(
                fontSize: MediaQuery.of(context).size.width < 350 ? 12 :
                MediaQuery.of(context).size.width < 400 ? 13 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEventDialog(BuildContext context, DateTime selectedDate) {
    final titleController = TextEditingController();
    final startTimeController = TextEditingController(text: '09:00');
    final endTimeController = TextEditingController(text: '10:00');
    final tempController = TextEditingController(text: '22');

    final timeOptions = _generateTimeOptions();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Event for ${DateFormat('MMM dd, yyyy').format(selectedDate)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event Title',
                    hintText: 'Enter event title',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: startTimeController.text,
                        items: timeOptions.map((time) {
                          return DropdownMenuItem<String>(
                            value: time,
                            child: Text(time),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            startTimeController.text = value;
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Start Time',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: endTimeController.text,
                        items: timeOptions.map((time) {
                          return DropdownMenuItem<String>(
                            value: time,
                            child: Text(time),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            endTimeController.text = value;
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'End Time',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tempController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Temperature (°C)',
                    hintText: 'Enter temperature',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an event title')),
                  );
                  return;
                }
                final newEvent = {
                  'buildingId': _buildingId,
                  'floorPlanId': _floorPlanId,
                  'title': titleController.text.trim(),
                  'date': selectedDate.toIso8601String(),
                  'startTime': startTimeController.text.trim(),
                  'endTime': endTimeController.text.trim(),
                  'temp': int.tryParse(tempController.text.trim()) ?? 22,
                  'finished': false,
                };
                try {
                  await MongoService.addEvent(newEvent);
                  await _loadEvents();
                  Navigator.pop(context);
                  AnimatedFeedback.showSuccess(context);
                } catch (e) {
                  AnimatedFeedback.showError(context);
                }
              },
              child: const Text('Add Event'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(
      BuildContext context, Map<String, dynamic> event, {bool fromCalendarDialog = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Event"),
        content: Text("Are you sure you want to delete '${event['title']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final String? eventId = event['id'];
              if (eventId != null) {
                try {
                  await MongoService.deleteEvent(eventId);
                  // Close the confirmation dialog first
                  Navigator.of(context).pop();

                  // If called from calendar day events dialog, close that too
                  if (fromCalendarDialog) {
                    Navigator.of(context).pop();
                  }

                  AnimatedFeedback.showSuccess(context);
                  await _loadEvents(); // Refresh events list
                } catch (e) {
                  // Close the confirmation dialog first
                  Navigator.of(context).pop();

                  // If called from calendar day events dialog, close that too
                  if (fromCalendarDialog) {
                    Navigator.of(context).pop();
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete event: $e')),
                    );
                  }
                }
              } else {
                Navigator.of(context).pop();
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedListView(BuildContext context) {
    List<Map<String, dynamic>> filteredEvents;

    if (_selectedFilter == 'Today') {
      filteredEvents = _allEvents.where((e) {
        final eventDate = DateTime.tryParse(e['date'] ?? '');
        if (eventDate == null) return false;
        final today = DateTime.now();
        final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
        final todayDay = DateTime(today.year, today.month, today.day);
        return eventDay.isAtSameMomentAs(todayDay);
      }).toList();
    } else if (_selectedFilter == 'Upcoming') {
      filteredEvents = _allEvents.where((e) {
        final eventDate = DateTime.tryParse(e['date'] ?? '');
        if (eventDate == null) return false;
        final today = DateTime.now();
        final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
        final todayDay = DateTime(today.year, today.month, today.day);
        return eventDay.isAfter(todayDay);
      }).toList();
    } else {
      filteredEvents = _allEvents.where((e) {
        final eventDate = DateTime.tryParse(e['date'] ?? '');
        if (eventDate == null) return false;
        final today = DateTime.now();
        final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);
        final todayDay = DateTime(today.year, today.month, today.day);
        return eventDay.isBefore(todayDay);
      }).toList();
    }

    // REMOVE THE DUPLICATE FILTER CONTAINER FROM HERE
    return _buildSimpleEventList(filteredEvents);
  }

  Widget _buildSimpleEventList(List<Map<String, dynamic>> events) {
    if (events.isEmpty) {
      return Container(
        height: 200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note,
              size: MediaQuery.of(context).size.width < 350 ? 56 :
              MediaQuery.of(context).size.width < 400 ? 60 : 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No events',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: MediaQuery.of(context).size.width < 350 ? 16 :
                MediaQuery.of(context).size.width < 400 ? 17 : 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: events.map((event) => _buildSimpleEventCard(context, event)).toList(),
    );
  }


  Widget _buildSimpleEventCard(BuildContext context, Map<String, dynamic> event) {
    final date = DateFormat('MMM dd, yyyy').format(DateTime.parse(event['date'] as String));
    final title = event['title'] as String? ?? 'Untitled Event';
    final isFinished = event['finished'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (isFinished)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Completed',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                    onPressed: () => _showDeleteConfirmationDialog(context, event, fromCalendarDialog: false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    date,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${event['startTime']} - ${event['endTime']}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final Function(DateTime) onMonthChanged;

  const _MonthSelector({
    Key? key,
    required this.selectedMonth,
    required this.onMonthChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return Container(
      width: MediaQuery.of(context).size.width * 0.5,
      height: MediaQuery.of(context).size.height * 0.05,// 50% of screen width
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, size: 20),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            onPressed: () {
              final newMonth = DateTime(
                selectedMonth.year,
                selectedMonth.month - 1,
              );
              onMonthChanged(newMonth);
            },
          ),
          Flexible(
            child: Text(
              '${months[selectedMonth.month - 1]} ${selectedMonth.year}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontSize: MediaQuery.of(context).size.width * 0.035, // 3.5% of screen width
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, size: 20),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            onPressed: () {
              final newMonth = DateTime(
                selectedMonth.year,
                selectedMonth.month + 1,
              );
              onMonthChanged(newMonth);
            },
          ),
        ],
      ),
    );
  }
}

int getWeeksInMonth(DateTime date) {
  final firstDay = DateTime(date.year, date.month, 1);
  final lastDay = DateTime(date.year, date.month + 1, 0);
  final firstDayOfWeek = firstDay.weekday % 7; // 0 = Sunday
  final totalDays = lastDay.day;

  return ((firstDayOfWeek + totalDays) / 7).ceil() + 1;
}