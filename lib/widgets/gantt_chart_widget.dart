import 'package:flutter/material.dart';
import '../models/production_plan.dart';

class GanttChartWidget extends StatefulWidget {
  final List<GanttPhase> phases;
  final List<GanttPhaseExtended>? extendedPhases; // For additional timeline info
  final ViewMode viewMode;
  final Function(GanttPhase)? onPhaseEdit;
  final Function(ScrollController)? onControllerReady; // Callback for scroll controller

  const GanttChartWidget({
    super.key,
    required this.phases,
    required this.viewMode,
    this.extendedPhases,
    this.onPhaseEdit,
    this.onControllerReady,
  });

  @override
  State<GanttChartWidget> createState() => _GanttChartWidgetState();
}

class _GanttChartWidgetState extends State<GanttChartWidget> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _horizontalScrollController2 = ScrollController(); // For header sync
  final ScrollController _verticalScrollController = ScrollController();
  final double _phaseRowHeight = 80.0;
  final double _leftColumnWidth = 150.0; // Balanced width
  final double _headerHeight = 40.0; // Reduced from 60.0 to 40.0 (2/3 of original)

  @override
  void initState() {
    super.initState();
    
    // Notify parent about scroll controller
    if (widget.onControllerReady != null) {
      widget.onControllerReady!(_horizontalScrollController);
    }
    
    // Synchronize horizontal scrolling between header and body
    _horizontalScrollController.addListener(() {
      if (_horizontalScrollController2.hasClients && 
          !_horizontalScrollController2.position.isScrollingNotifier.value) {
        _horizontalScrollController2.jumpTo(_horizontalScrollController.offset);
      }
    });
    
    _horizontalScrollController2.addListener(() {
      if (_horizontalScrollController.hasClients &&
          !_horizontalScrollController.position.isScrollingNotifier.value) {
        _horizontalScrollController.jumpTo(_horizontalScrollController2.offset);
      }
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _horizontalScrollController2.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  DateTime? get _earliestDate {
    if (widget.phases.isEmpty) return DateTime.now();
    
    // Check if any phases have actual dates
    final phasesWithDates = widget.phases.where((phase) => phase.start != null);
    if (phasesWithDates.isNotEmpty) {
      return phasesWithDates
          .map((phase) => phase.start!)
          .fold<DateTime?>(null, (prev, curr) => 
              prev == null ? curr : (curr.isBefore(prev) ? curr : prev));
    }
    
    // If no phases have dates, create a mock timeline starting today
    return DateTime.now();
  }

  DateTime? get _latestDate {
    if (widget.phases.isEmpty) return DateTime.now();
    
    // Check if any phases have actual dates
    final phasesWithDates = widget.phases.where((phase) => phase.end != null);
    if (phasesWithDates.isNotEmpty) {
      return phasesWithDates
          .map((phase) => phase.end!)
          .fold<DateTime?>(null, (prev, curr) => 
              prev == null ? curr : (curr.isAfter(prev) ? curr : prev));
    }
    
    // If no phases have dates, create a mock timeline
    // Each phase gets 7 days, total timeline spans all phases
    final mockDuration = widget.phases.length * 7;
    return DateTime.now().add(Duration(days: mockDuration));
  }

  int get _totalDays {
    final earliest = _earliestDate;
    final latest = _latestDate;
    if (earliest == null || latest == null) return 30;
    
    // Check if we're using real dates or mock dates
    final hasRealDates = widget.phases.any((phase) => phase.start != null && phase.end != null);
    if (hasRealDates) {
      final totalDays = latest.difference(earliest).inDays + 1;
      // For month view, calculate weeks (4 weeks per month)
      if (widget.viewMode == ViewMode.month) {
        final months = (totalDays / 30).ceil();
        return months * 4; // 4 weeks per month
      }
      return totalDays;
    } else {
      // For phases without dates, show a reasonable timeline
      if (widget.viewMode == ViewMode.month) {
        return widget.phases.length; // Each phase gets 1 week
      }
      return widget.phases.length * 7; // 7 days per phase for week view
    }
  }

  double get _dayWidth {
    switch (widget.viewMode) {
      case ViewMode.week:
        return 40.0; // Reduced from 80.0 to half
      case ViewMode.month:
        return 50.0; // Reduced from 100.0 to half
    }
  }

  double get _timelineWidth {
    final calculatedWidth = _totalDays * _dayWidth;
    // Ensure much wider timeline for proper momentum scrolling
    final minWidth = MediaQuery.of(context).size.width * 3; // 3x screen width minimum
    return calculatedWidth < minWidth ? minWidth : calculatedWidth;
  }

  @override
  Widget build(BuildContext context) {
    print('Building GanttChartWidget with ${widget.phases.length} phases');
    print('Timeline width: $_timelineWidth, Total days: $_totalDays, Day width: $_dayWidth');
    
    if (widget.phases.isEmpty) {
      print('No phases to display');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No production data available', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final earliest = _earliestDate;
    final latest = _latestDate;
    final totalDays = _totalDays;
    
    print('Timeline info: earliest=$earliest, latest=$latest, totalDays=$totalDays');
    print('Timeline width: $_timelineWidth, dayWidth: $_dayWidth');
    
    for (int i = 0; i < widget.phases.length; i++) {
      final phase = widget.phases[i];
      print('Phase $i: ${phase.name}, start=${phase.start}, end=${phase.end}');
    }

    return Column(
      children: [
        // Show warning if no dates are available
        if (!widget.phases.any((phase) => phase.start != null && phase.end != null))
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.orange[100],
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.orange[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No date information available - showing phase sequence with estimated timeline',
                    style: TextStyle(color: Colors.orange[700], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

        // Header row
        Container(
          height: _headerHeight + 35, // Reduced height for Today marker
          child: Row(
            children: [
              // Fixed left header
              Container(
                width: _leftColumnWidth,
                decoration: BoxDecoration(
                  color: const Color(0xFFC00000),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Center(
                  child: Text(
                    'PO/Phase',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // Scrollable timeline header
              Expanded(
                child: Scrollbar(
                  controller: _horizontalScrollController2,
                  scrollbarOrientation: ScrollbarOrientation.top,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController2,
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: Container(
                      width: _timelineWidth,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC00000),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: _buildTimelineHeaderContent(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Gantt chart body
        Expanded(
          child: SingleChildScrollView(
            controller: _verticalScrollController,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              height: widget.phases.length * _phaseRowHeight,
              child: Row(
                children: [
                  // Fixed left column
                  SizedBox(
                    width: _leftColumnWidth,
                    child: _buildLeftColumnFixed(),
                  ),
                  // Scrollable timeline
                  Expanded(
                    child: Scrollbar(
                      controller: _horizontalScrollController,
                      scrollbarOrientation: ScrollbarOrientation.bottom,
                      child: SingleChildScrollView(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        child: SizedBox(
                          width: _timelineWidth,
                          child: _buildTimelineFixed(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineHeaderContent() {
    final earliest = _earliestDate;
    if (earliest == null) return Container();

    List<Widget> headerItems = [];
    
    if (widget.viewMode == ViewMode.month) {
      // Month view: show weeks 1-4 for each month
      DateTime current = DateTime(earliest.year, earliest.month, 1);
      int totalWeeks = _totalDays; // Total weeks to display
      
      for (int i = 0; i < totalWeeks; i++) {
        int weekInMonth = (i % 4) + 1; // Week 1-4
        
        // Move to next month every 4 weeks
        if (i > 0 && i % 4 == 0) {
          current = DateTime(current.year, current.month + 1, 1);
        }
        
        headerItems.add(
          Container(
            width: _dayWidth,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'W$weekInMonth',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _getMonthAbbreviation(current.month),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      // Week view: show daily timeline
      DateTime current = DateTime(earliest.year, earliest.month, earliest.day);
      
      for (int i = 0; i < _totalDays; i++) {
        headerItems.add(
          Container(
            width: _dayWidth,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.white.withOpacity(0.3)),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${current.day}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _getMonthAbbreviation(current.month),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        );
        current = current.add(const Duration(days: 1));
      }
    }

    // Return timeline header with Today marker overlay
    return SizedBox(
      height: _headerHeight + 35, // Reduced height for Today marker above
      child: Stack(
        children: [
          // Today marker positioned above header dates
          if (_shouldShowTodayMarker())
            Positioned(
              left: _getTodayOffset(),
              top: 0, // At the top
              child: Builder(
                builder: (context) {
                  final finalOffset = _getTodayOffset();
                  print('Today marker embedded in timeline: offset=$finalOffset');
                  return _buildTodayMarker();
                },
              ),
            ),
          // Header dates positioned below Today marker
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: _headerHeight,
            child: Row(
              children: headerItems,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumnFixed() {
    return Column(
      children: widget.phases.asMap().entries.map((entry) {
        final index = entry.key;
        final phase = entry.value;
        return Container(
          height: _phaseRowHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
            color: index % 2 == 0 ? Colors.grey[50] : Colors.white,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Text(
              phase.poNumber,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFFC00000),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              phase.name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Show actual phase dates instead of timeline description
            Text(
              _getDurationInfo(index),
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[700],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                _getStatusIcon(phase.status),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    phase.status,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            ],
            ),
        );
      }).toList(),
    );
  }

  Widget _buildTimelineFixed() {
    final earliest = _earliestDate;
    if (earliest == null) return Container();

    return Column(
      children: widget.phases.asMap().entries.map((entry) {
        final index = entry.key;
        final phase = entry.value;
        return Container(
          height: _phaseRowHeight,
          width: _timelineWidth,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
            color: index % 2 == 0 ? Colors.grey[50] : Colors.white,
          ),
          child: Stack(
            children: [
              // Grid lines
              _buildGridLines(),
              // Phase bar
              _buildPhaseBar(phase, earliest, index),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Get duration info based on view mode
  String _getDurationInfo(int phaseIndex) {
    if (phaseIndex >= widget.phases.length) {
      return '';
    }
    
    final phase = widget.phases[phaseIndex];
    
    // Show actual phase dates if available
    if (phase.start != null && phase.end != null) {
      final startDate = '${phase.start!.day.toString().padLeft(2, '0')}-${phase.start!.month.toString().padLeft(2, '0')}-${phase.start!.year}';
      final endDate = '${phase.end!.day.toString().padLeft(2, '0')}-${phase.end!.month.toString().padLeft(2, '0')}-${phase.end!.year}';
      return '$startDate to $endDate';
    }
    
    // Fallback to duration in days
    if (widget.extendedPhases != null && phaseIndex < widget.extendedPhases!.length) {
      final extendedPhase = widget.extendedPhases![phaseIndex];
      
      switch (widget.viewMode) {
        case ViewMode.week:
          return extendedPhase.durationWeeks != null 
              ? '${extendedPhase.durationWeeks!.toStringAsFixed(1)} weeks'
              : '${extendedPhase.duration} days';
        case ViewMode.month:
          return extendedPhase.duration > 0 
              ? '${extendedPhase.duration} days'
              : 'Duration not specified';
      }
    }
    
    return '${phase.duration} days';
  }

  Widget _buildGridLines() {
    List<Widget> lines = [];
    
    int totalUnits = widget.viewMode == ViewMode.month ? _totalDays : _totalDays;
    
    for (int i = 0; i < totalUnits; i++) {
      lines.add(
        Positioned(
          left: i * _dayWidth,
          top: 0,
          bottom: 0,
          child: Container(
            width: _dayWidth,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: Colors.grey[300]!,
                  width: 0.5,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(children: lines);
  }

  Widget _buildPhaseBar(GanttPhase phase, DateTime earliest, int phaseIndex) {
    double startOffset;
    double barWidth;
    
    if (widget.viewMode == ViewMode.month) {
      // Month view: position based on weeks
      if (phase.start != null && phase.end != null) {
        // Calculate which week of which month this phase starts
        final monthsDiff = (phase.start!.year - earliest.year) * 12 + 
                          (phase.start!.month - earliest.month);
        final weekInMonth = ((phase.start!.day - 1) / 7).floor();
        startOffset = (monthsDiff * 4 + weekInMonth).toDouble();
        
        // Calculate width in weeks
        final durationWeeks = (phase.duration / 7).ceil();
        barWidth = durationWeeks * _dayWidth;
      } else {
        // Mock timeline: each phase gets 1 week
        startOffset = phaseIndex.toDouble();
        barWidth = _dayWidth;
      }
    } else {
      // Week view: use day-based positioning
      if (phase.start != null && phase.end != null && phase.duration > 0) {
        // Use real dates if available
        startOffset = phase.start!.difference(earliest).inDays.toDouble();
        barWidth = phase.duration * _dayWidth;
      } else {
        // Create mock timeline for phases without dates
        // Each phase gets 7 days, positioned sequentially
        startOffset = phaseIndex * 7.0;
        barWidth = 7 * _dayWidth; // 7 days per phase
      }
    }

    return Positioned(
      left: startOffset * _dayWidth,
      top: 15,
      child: GestureDetector(
        onTap: () => widget.onPhaseEdit?.call(phase),
        child: Container(
          width: barWidth,
          height: 30,
          decoration: BoxDecoration(
            color: _getStatusColor(phase.status),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                // Progress bar
                if (phase.progress > 0)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: barWidth * (phase.progress / 100),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _getStatusColor(phase.status).withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                // Phase text
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        phase.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                // Progress percentage
                if (phase.progress > 0)
                  Positioned(
                    right: 4,
                    top: 2,
                    child: Text(
                      '${phase.progress}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.orange;
      case 'delayed':
        return Colors.red;
      case 'not started':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Widget _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Icon(Icons.check_circle, color: Colors.green, size: 12);
      case 'in progress':
        return const Icon(Icons.access_time, color: Colors.orange, size: 12);
      case 'delayed':
        return const Icon(Icons.warning, color: Colors.red, size: 12);
      case 'not started':
        return const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 12);
      default:
        return const Icon(Icons.schedule, color: Colors.blue, size: 12);
    }
  }

  String _getMonthAbbreviation(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  bool _shouldShowTodayMarker() {
    final today = DateTime.now();
    final earliest = _earliestDate;
    final latest = _latestDate;
    
    print('=== Today Marker Debug ===');
    print('Today: $today');
    print('Earliest: $earliest');
    print('Latest: $latest');
    print('View Mode: ${widget.viewMode}');
    
    if (earliest == null || latest == null) {
      print('No dates available, hiding marker');
      return false;
    }
    
    // Check if any phases have real dates
    final hasRealDates = widget.phases.any((phase) => phase.start != null && phase.end != null);
    print('Has real dates: $hasRealDates');
    
    if (hasRealDates) {
      // For real dates, check if today falls within the timeline
      final withinRange = today.isAfter(earliest.subtract(const Duration(days: 1))) && 
                         today.isBefore(latest.add(const Duration(days: 1)));
      print('Today within range: $withinRange');
      return withinRange;
    } else {
      print('Using mock timeline');
      return false; // Focus only on real dates
    }
  }
  
  double _getTodayOffset() {
    final today = DateTime.now();
    final earliest = _earliestDate;
    
    if (earliest == null) {
      print('No earliest date, offset = 0');
      return 0;
    }
    
    // Check if phases have real dates
    final hasRealDates = widget.phases.any((phase) => phase.start != null && phase.end != null);
    
    if (hasRealDates) {
      // Use real date calculations only
      if (widget.viewMode == ViewMode.month) {
        // Month view: calculate week offset
        final daysDiff = today.difference(earliest).inDays;
        final monthsDiff = (daysDiff / 30).floor();
        final dayInMonth = daysDiff % 30;
        final weekInMonth = (dayInMonth / 7).floor();
        final offset = (monthsDiff * 4 + weekInMonth) * _dayWidth;
        print('Month view offset: daysDiff=$daysDiff, monthsDiff=$monthsDiff, weekInMonth=$weekInMonth, offset=$offset');
        return offset;
      } else {
        // Week view: calculate day offset
        final daysDiff = today.difference(earliest).inDays;
        final offset = daysDiff * _dayWidth;
        print('Week view offset: daysDiff=$daysDiff, dayWidth=$_dayWidth, offset=$offset');
        return offset;
      }
    } else {
      print('No real dates, hiding marker');
      return 0;
    }
  }
  
  Widget _buildTodayMarker() {
    return Container(
      width: _dayWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Today text at the top
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Today',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Inverted triangle arrow pointing down (no space)
          Transform.translate(
            offset: const Offset(0, -2), // Move arrow up to remove space
            child: Icon(
              Icons.arrow_drop_down,
              color: Colors.red,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}