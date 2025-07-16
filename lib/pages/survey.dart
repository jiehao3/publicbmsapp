import 'package:bmsapp/services/mongodb.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SurveyFeedbackTab extends StatefulWidget {
  final String building;

  const SurveyFeedbackTab({Key? key, required this.building}) : super(key: key);

  @override
  State<SurveyFeedbackTab> createState() => _SurveyFeedbackTabState();
}

class _SurveyFeedbackTabState extends State<SurveyFeedbackTab> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> feedbackList = [];
  bool isLoading = true;
  String _selectedFilter = 'Today';

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadFeedback() async {
    setState(() => isLoading = true);
    try {
      final surveys = await MongoService.fetchSurveyByBuildingName(widget.building);
      if (mounted) {
        setState(() {
          feedbackList = surveys;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading feedback: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          feedbackList = [
            {
              'user': 'John D.',
              'units': ['FCU-1', 'FCU-3'],
              'rating': 8.2,
              'comment': 'Meeting room 2 was extremely warm during the afternoon session. The AC system seems to struggle with maintaining consistent temperature.',
              'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
            },
            {
              'user': 'Anonymous',
              'units': ['FCU-2'],
              'rating': 6.5,
              'comment': 'Generally comfortable temperature in the open office area, though it could be slightly cooler.',
              'timestamp': DateTime.now().subtract(const Duration(hours: 4)),
            },
            {
              'user': 'Sarah M.',
              'units': ['FCU-4', 'FCU-5'],
              'rating': 2.3,
              'comment': 'Quite cold in the executive offices. Multiple complaints from staff about discomfort.',
              'timestamp': DateTime(2025, 4, 5, 14, 30),
            },
            {
              'user': 'Jiehao L.',
              'units': ['FCU-4', 'FCU-5'],
              'rating': 1.0,
              'comment': 'Freezing cold in the executive offices. Urgent attention needed.',
              'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
            },
          ];
        });
      }
    }
  }

  Map<String, dynamic> _getStatistics() {
    final filteredData = _filteredList();
    if (filteredData.isEmpty || filteredData.first.containsKey('isDummy')) {
      return {
        'totalFeedback': 0,
        'averageRating': 0.0,
      };
    }
    final totalFeedback = filteredData.length;
    final averageRating = filteredData
        .map((f) => f['rating'] as double)
        .reduce((a, b) => a + b) /
        totalFeedback;

    return {
      'totalFeedback': totalFeedback,
      'averageRating': averageRating,
    };
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700 || screenWidth < 400;


    return RefreshIndicator(
      onRefresh: _loadFeedback,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            _buildFilterSection(),
            SizedBox(height: isSmallScreen ? 12 : 16),
            _buildStatisticsCards(),
            SizedBox(height: isSmallScreen ? 16 : 20),
            _buildFeedbackSection(),
          ],
        ),
      ),
    );
  }



  Widget _buildFilterSection() {
    return Container(
      height: 50,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedFilter = 'Today');
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _selectedFilter == 'Today'
                        ? LinearGradient(
                      colors: [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.today_outlined,
                          color: _selectedFilter == 'Today'
                              ? Colors.white
                              : const Color(0xFF6B7280),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Today',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _selectedFilter == 'Today'
                                ? Colors.white
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedFilter = 'Past');
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: _selectedFilter == 'Past'
                        ? LinearGradient(
                      colors: [const Color(0xFF2563EB), const Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_outlined,
                          color: _selectedFilter == 'Past'
                              ? Colors.white
                              : const Color(0xFF6B7280),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Past',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _selectedFilter == 'Past'
                                ? Colors.white
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, bool isSmallScreen) {
    final isSelected = _selectedFilter == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _selectedFilter = label);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            vertical: isSmallScreen ? 10 : 12,
            horizontal: isSmallScreen ? 12 : 16,
          ),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: isSmallScreen ? 16 : 18,
              ),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: isSmallScreen ? 13 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    final stats = _getStatistics();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Feedback',
            '${stats['totalFeedback']}',
            Icons.chat_bubble_outline,
            Colors.blue,
            isSmallScreen,
          ),
        ),
        SizedBox(width: isSmallScreen ? 8 : 12),
        Expanded(
          child: _buildStatCard(
            'Avg Rating',
            '${stats['averageRating'].toStringAsFixed(1)}',
            Icons.thermostat_rounded,
            _getRatingColor(stats['averageRating']),
            isSmallScreen,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: isSmallScreen ? 18 : 20),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          SizedBox(height: isSmallScreen ? 2 : 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? 10 : 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    final filteredFeedback = _filteredList();
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700 || screenWidth < 400;

    if (filteredFeedback.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.feedback_outlined,
              color: Colors.blueGrey,
              size: isSmallScreen ? 18 : 20,
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            Expanded(
              child: Text(
                'Recent Feedback',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                  fontSize: isSmallScreen ? 16 : 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        SizedBox(
          height: screenHeight * (isSmallScreen ? 0.45 : 0.5),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: filteredFeedback.length,
            itemBuilder: (context, index) {
              final feedback = filteredFeedback[index];
              return Padding(
                padding: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
                child: _buildFeedbackCard(feedback, context),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _filteredList() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final filtered = feedbackList.where((feedback) {
      final rawTimestamp = feedback['timestamp'];
      DateTime timestamp;
      if (rawTimestamp is DateTime) {
        timestamp = rawTimestamp;
      } else if (rawTimestamp is String) {
        try {
          timestamp = DateTime.parse(rawTimestamp).toLocal();
        } catch (_) {
          timestamp = DateTime.now();
        }
      } else {
        timestamp = DateTime.now();
      }

      if (_selectedFilter == 'Today') {
        return timestamp.year == today.year &&
            timestamp.month == today.month &&
            timestamp.day == today.day;
      } else if (_selectedFilter == 'Past') {
        return timestamp.isBefore(today);
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return [
        {
          'user': 'No Data',
          'units': [],
          'rating': 5.0,
          'comment': 'No feedback available for the selected time period',
          'timestamp': null,
          'isDummy': true,
        },
      ];
    }

    filtered.sort((a, b) {
      final aTime = a['timestamp'] as DateTime? ?? DateTime.now();
      final bTime = b['timestamp'] as DateTime? ?? DateTime.now();
      return bTime.compareTo(aTime);
    });

    return filtered;
  }

  Widget _buildFeedbackCard(Map<String, dynamic> feedback, BuildContext context) {
    final bool isDummy = feedback.containsKey('isDummy') && feedback['isDummy'] == true;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700 || screenWidth < 400;

    if (isDummy) {
      return _buildEmptyFeedbackCard();
    }

    final double rating = feedback['rating'] as double;
    final Color ratingColor = _getRatingColor(rating);
    final String descriptor = _getRatingDescriptor(rating);

    return Card(
      elevation: isSmallScreen ? 4 : 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 2 : 4,
        vertical: isSmallScreen ? 4 : 8,
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    feedback['user'] ?? 'Anonymous',
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 13 : 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatDate(feedback['timestamp'] ?? DateTime.now()),
                  style: TextStyle(
                    color: Colors.blueGrey[400],
                    fontSize: isSmallScreen ? 10 : 12,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Row(
              children: [
                Icon(
                  Icons.thermostat_rounded,
                  color: ratingColor,
                  size: isSmallScreen ? 20 : 24,
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Text(
                  descriptor,
                  style: TextStyle(
                    color: ratingColor,
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if ((feedback['units'] as List).isNotEmpty) ...[
              SizedBox(height: isSmallScreen ? 6 : 8),
              Wrap(
                spacing: isSmallScreen ? 4 : 6,
                runSpacing: isSmallScreen ? 2 : 4,
                children: (feedback['units'] as List)
                    .map((unit) => Chip(
                  label: Text(
                    unit,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmallScreen ? 10 : 12,
                    ),
                  ),
                  backgroundColor: Colors.blue[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ))
                    .toList(),
              ),
            ],
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              feedback['comment'],
              maxLines: isSmallScreen ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDummy ? Colors.grey : Colors.blueGrey[700],
                height: 1.4,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFeedbackCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.grey.shade400,
            size: isSmallScreen ? 20 : 24,
          ),
          SizedBox(width: isSmallScreen ? 10 : 12),
          Text(
            'No feedback available',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: isSmallScreen ? 12 : 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Center(
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.feedback_outlined,
                size: isSmallScreen ? 36 : 48,
                color: Colors.blue.shade300,
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
            Text(
              'No Feedback Available',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade700,
                fontSize: isSmallScreen ? 16 : 18,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              'Be the first to share your experience with\nthe building\'s climate control system',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.4,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRatingColor(double rating) {
    if (rating < 2) return Colors.blue.shade600; // Very Cold
    if (rating < 4) return Colors.lightBlue; // Slightly Cold
    if (rating < 6) return Colors.green.shade600; // Great
    if (rating < 8) return Colors.orange.shade600; // Slightly Hot
    return Colors.red.shade700; // Very Hot
  }

  String _getRatingDescriptor(double rating) {
    if (rating < 2) return 'Very Cold';
    if (rating < 4) return 'Slightly Cold';
    if (rating < 6) return 'Great';
    if (rating < 8) return 'Slightly Hot';
    return 'Very Hot';
  }

  String _formatDate(dynamic date) {
    DateTime actualDate;

    if (date is DateTime) {
      actualDate = date;
    } else if (date is String) {
      try {
        actualDate = DateTime.parse(date).toLocal();
      } catch (e) {
        actualDate = DateTime.now();
      }
    } else {
      actualDate = DateTime.now();
    }

    final now = DateTime.now();
    final difference = now.difference(actualDate);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return "${actualDate.day}/${actualDate.month}/${actualDate.year}";
    }
  }
}