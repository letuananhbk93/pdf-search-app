import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../models/production_plan.dart';
import '../widgets/gantt_chart_widget.dart';

class ProductionPlanScreen extends ConsumerStatefulWidget {
  const ProductionPlanScreen({super.key});

  @override
  ConsumerState<ProductionPlanScreen> createState() => _ProductionPlanScreenState();
}

class _ProductionPlanScreenState extends ConsumerState<ProductionPlanScreen> {
  final ApiService _apiService = ApiService();
  
  List<String> _projects = [];
  String? _selectedProject;
  List<GanttPhase> _phases = [];
  List<GanttPhaseExtended> _extendedPhases = [];
  ScrollController? _ganttScrollController;
  ViewMode _viewMode = ViewMode.week;
  bool _isLoadingProjects = true;
  bool _isLoadingData = false;
  String? _error;
  String? _lastUpdateDate;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    // Don't wait for last update date - fetch it in background
    _fetchLastUpdateDate().catchError((e) {
      print('Error fetching last update date: $e');
      // Ignore errors for last update date - it's not critical
    });
  }

  void _jumpToToday() {
    if (_ganttScrollController != null && _phases.isNotEmpty) {
      final today = DateTime.now();
      final earliest = _getEarliestDate();
      
      print('=== Jump to Today Debug ===');
      print('Today: $today');
      print('Earliest: $earliest');
      print('View Mode: $_viewMode');
      print('Scroll controller attached: ${_ganttScrollController!.hasClients}');
      
      if (earliest != null) {
        double scrollPosition = 0;
        
        if (_viewMode == ViewMode.week) {
          // Week view: exact same calculation as in gantt widget
          final daysDiff = today.difference(earliest).inDays;
          scrollPosition = daysDiff * 40.0; // 40px per day in week view
          print('Week view scroll: daysDiff=$daysDiff, scrollPosition=$scrollPosition');
        } else {
          // Month view: exact same calculation as in gantt widget
          final daysDiff = today.difference(earliest).inDays;
          final monthsDiff = (daysDiff / 30).floor();
          final dayInMonth = daysDiff % 30;
          final weekInMonth = (dayInMonth / 7).floor();
          scrollPosition = (monthsDiff * 4 + weekInMonth) * 50.0;
          print('Month view scroll: daysDiff=$daysDiff, monthsDiff=$monthsDiff, weekInMonth=$weekInMonth, scrollPosition=$scrollPosition');
        }
        
        // Center the today marker on screen
        final screenWidth = MediaQuery.of(context).size.width - 150; // minus left column width
        final centeredPosition = scrollPosition - (screenWidth / 2);
        final clampedPosition = centeredPosition.clamp(0.0, _ganttScrollController!.position.maxScrollExtent);
        
        print('Screen width: $screenWidth, centered: $centeredPosition, final: $clampedPosition');
        print('Max scroll extent: ${_ganttScrollController!.position.maxScrollExtent}');
        print('Current scroll position: ${_ganttScrollController!.offset}');
        
        // Use animateTo to smoothly scroll to the position
        _ganttScrollController!.animateTo(
          clampedPosition,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        ).then((_) {
          print('Jump to Today animation completed, final position: ${_ganttScrollController!.offset}');
        });
      }
    } else {
      print('Cannot jump to today: controller=${_ganttScrollController != null}, phases=${_phases.length}');
    }
  }
  
  DateTime? _getEarliestDate() {
    if (_phases.isEmpty) return null;
    
    final phasesWithDates = _phases.where((phase) => phase.start != null);
    if (phasesWithDates.isNotEmpty) {
      return phasesWithDates
          .map((phase) => phase.start!)
          .fold<DateTime?>(null, (prev, curr) => 
              prev == null ? curr : (curr.isBefore(prev) ? curr : prev));
    }
    
    return DateTime.now();
  }

  // Fetch last update date from API
  Future<void> _fetchLastUpdateDate([String? category]) async {
    try {
      // Add timeout to prevent hanging
      final updateInfo = await _apiService.getLastUpdateInfo(category ?? 'production_plan')
          .timeout(const Duration(seconds: 10));
      setState(() {
        _lastUpdateDate = updateInfo['last_update'] ?? 'Unknown';
      });
    } catch (e) {
      print('Last update date fetch failed: $e');
      setState(() {
        _lastUpdateDate = 'Unknown';
      });
    }
  }

  Future<void> _loadProjects() async {
    setState(() {
      _isLoadingProjects = true;
      _error = null;
    });

    try {
      final projects = await _apiService.getProductionPlanProjects()
          .timeout(const Duration(seconds: 30));
      setState(() {
        _projects = projects;
        _isLoadingProjects = false;
      });
      
      // Select first project in background to show UI faster
      if (projects.isNotEmpty) {
        // Set selected project immediately but load data in background
        setState(() {
          _selectedProject = projects.first;
        });
        // Load project data in background without blocking UI
        _loadProjectData(projects.first).catchError((e) {
          print('Error loading initial project data: $e');
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingProjects = false;
      });
    }
  }

  Future<void> _loadOverallData() async {
    setState(() {
      _isLoadingData = true;
      _error = null;
    });

    try {
      print('Loading overall data for all POs with view mode: ${_viewMode.name}');
      
      // Load data for all projects
      final allPhases = <GanttPhase>[];
      final allExtendedPhases = <GanttPhaseExtended>[];
      
      // Get all available projects (PO2 to PO9)
      final projects = _projects.where((project) => 
        project.toLowerCase().startsWith('po') && 
        project != 'PO1' // Exclude PO1 if it exists
      ).toList();
      
      print('Loading data for projects: $projects');
      
      for (String poNumber in projects) {
        try {
          print('Loading data for: $poNumber');
          
          // Fetch Gantt data for each project
          final ganttData = await _apiService.getGanttData(poNumber, viewMode: _viewMode.name)
              .timeout(const Duration(seconds: 15));
          
          // Parse the response
          final response = ProductionPlanResponse.fromJson(ganttData);
          
          // Add project prefix to phase names to distinguish between POs
          final extendedPhases = response.phases.cast<GanttPhaseExtended>();
          for (var extendedPhase in extendedPhases) {
            // Create a copy with modified name and unique ID
            final modifiedPhase = GanttPhaseExtended(
              id: extendedPhase.id + (allExtendedPhases.length * 1000), // Ensure unique IDs
              poNumber: '$poNumber - ${extendedPhase.poNumber}',
              name: '${extendedPhase.name}',
              status: extendedPhase.status,
              progress: extendedPhase.progress,
              duration: extendedPhase.duration,
              start: extendedPhase.start,
              end: extendedPhase.end,
              notes: extendedPhase.notes,
              viewMode: extendedPhase.viewMode,
              weekLabel: extendedPhase.weekLabel,
              weekStart: extendedPhase.weekStart,
              weekEnd: extendedPhase.weekEnd,
              durationWeeks: extendedPhase.durationWeeks,
              weekNumber: extendedPhase.weekNumber,
              timelineDescription: extendedPhase.timelineDescription,
              startWeekInfo: extendedPhase.startWeekInfo,
              endWeekInfo: extendedPhase.endWeekInfo,
            );
            
            allExtendedPhases.add(modifiedPhase);
            allPhases.add(modifiedPhase.toGanttPhase());
          }
          
          print('Successfully loaded ${extendedPhases.length} phases from $poNumber');
        } catch (e) {
          print('Error loading data for $poNumber: $e');
          // Continue with other projects even if one fails
        }
      }
      
      // Sort phases by start date for better timeline visualization
      allPhases.sort((a, b) {
        if (a.start == null && b.start == null) return 0;
        if (a.start == null) return 1;
        if (b.start == null) return -1;
        return a.start!.compareTo(b.start!);
      });
      
      allExtendedPhases.sort((a, b) {
        if (a.start == null && b.start == null) return 0;
        if (a.start == null) return 1;
        if (b.start == null) return -1;
        return a.start!.compareTo(b.start!);
      });
      
      print('Overall data loaded: ${allPhases.length} total phases from ${projects.length} projects');
      
      setState(() {
        _phases = allPhases;
        _extendedPhases = allExtendedPhases;
        _isLoadingData = false;
      });
      
      // Update last update date for overall view
      _fetchLastUpdateDate('overall').catchError((e) {
        print('Error fetching overall update date: $e');
      });
    } catch (e) {
      print('Error loading overall data: $e');
      setState(() {
        _error = e.toString();
        _isLoadingData = false;
      });
    }
  }

  Future<void> _loadProjectData(String poNumber) async {
    setState(() {
      _isLoadingData = true;
      _error = null;
    });

    try {
      print('Loading project data for: $poNumber with view mode: ${_viewMode.name}');
      
      // Fetch Gantt data with view mode
      final ganttData = await _apiService.getGanttData(poNumber, viewMode: _viewMode.name)
          .timeout(const Duration(seconds: 15));
      print('Gantt data received: $ganttData');
      
      // Parse the response using the unified model
      final response = ProductionPlanResponse.fromJson(ganttData);
      
      // Convert to GanttPhase for compatibility with existing chart widget
      final phases = <GanttPhase>[];
      
      // Both view modes now return the same phase structure
      final extendedPhases = response.phases.cast<GanttPhaseExtended>();
      for (var extendedPhase in extendedPhases) {
        phases.add(extendedPhase.toGanttPhase());
      }
      
      print('Successfully parsed ${phases.length} phases');
      for (int i = 0; i < phases.length; i++) {
        final phase = phases[i];
        print('Phase $i: ${phase.name}, start=${phase.start}, end=${phase.end}, duration=${phase.duration}');
      }
      
      setState(() {
        _phases = phases;
        _extendedPhases = extendedPhases;
        _isLoadingData = false;
      });
      
      // Fetch project-specific update date in background - don't block UI
      _fetchLastUpdateDate(poNumber.toLowerCase().replaceAll(' ', '_')).catchError((e) {
        print('Error fetching project-specific update date: $e');
        // Ignore errors - this is not critical for the main functionality
      });
    } catch (e) {
      print('Error loading project data: $e');
      setState(() {
        _error = e.toString();
        _isLoadingData = false;
      });
    }
  }

  void _selectProject(String project) {
    setState(() {
      _selectedProject = project;
    });
    
    if (project == 'Overall') {
      _loadOverallData();
    } else {
      _loadProjectData(project);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PRODUCTION PLAN',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFFC00000),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Last update date display
          if (_lastUpdateDate != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
              child: Center(
                child: Text(
                  'Updated: $_lastUpdateDate',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          // View mode toggle
          PopupMenuButton<ViewMode>(
            icon: const Icon(Icons.view_module, color: Colors.white),
            tooltip: 'View Mode',
            onSelected: (ViewMode mode) {
              setState(() {
                _viewMode = mode;
              });
              // Reload data when view mode changes
              if (_selectedProject != null) {
                if (_selectedProject == 'Overall') {
                  _loadOverallData();
                } else {
                  _loadProjectData(_selectedProject!);
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<ViewMode>>[
              PopupMenuItem<ViewMode>(
                value: ViewMode.week,
                child: Row(
                  children: [
                    Icon(Icons.view_week, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Week View'),
                    Spacer(),
                    if (_viewMode == ViewMode.week)
                      Icon(Icons.check, color: Color(0xFFC00000), size: 20),
                  ],
                ),
              ),
              PopupMenuItem<ViewMode>(
                value: ViewMode.month,
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Month View'),
                    Spacer(),
                    if (_viewMode == ViewMode.month)
                      Icon(Icons.check, color: Color(0xFFC00000), size: 20),
                  ],
                ),
              ),
            ],
          ),
          // Hamburger menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
            tooltip: 'Menu',
            onSelected: (String choice) {
              switch (choice) {
                case 'refresh':
                  if (_selectedProject != null) {
                    _loadProjectData(_selectedProject!);
                  } else {
                    _loadProjects();
                  }
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Refresh'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Project selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Text(
                  'Select Project: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedProject,
                    hint: const Text('Choose a project'),
                    isExpanded: true,
                    items: [
                      // Add Overall option at the top
                      const DropdownMenuItem<String>(
                        value: 'Overall',
                        child: Text(
                          'Overall (All POs)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC00000),
                          ),
                        ),
                      ),
                      // Add separator
                      const DropdownMenuItem<String>(
                        value: null,
                        enabled: false,
                        child: Divider(),
                      ),
                      // Individual projects
                      ..._projects.map((String project) {
                        return DropdownMenuItem<String>(
                          value: project,
                          child: Text(project),
                        );
                      }).toList(),
                    ],
                    onChanged: (String? newValue) {
                      if (newValue != null && newValue != '') {
                        _selectProject(newValue);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoadingProjects) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading projects...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error loading data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                  });
                  _loadProjects();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_projects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No projects available', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_selectedProject == null) {
      return const Center(
        child: Text(
          'Please select a project to view production plan',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    if (_isLoadingData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Loading $_selectedProject data...'),
          ],
        ),
      );
    }

    // Chart content
    if (_isLoadingData) {
      return const Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading project data...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_phases.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timeline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _selectedProject != null 
                  ? 'No production plan data for $_selectedProject'
                  : 'Select a project to view production plan',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Project info header
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue[50],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedProject!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC00000),
                ),
              ),
              const SizedBox(height: 8),
              // Jump to Today button
              ElevatedButton.icon(
                onPressed: _jumpToToday,
                icon: const Icon(Icons.today, size: 16),
                label: const Text('Jump to Today'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC00000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        // Gantt Chart
        Expanded(
          child: GanttChartWidget(
            key: ValueKey(_refreshKey),
            phases: _phases,
            extendedPhases: _extendedPhases,
            viewMode: _viewMode,
            onPhaseEdit: (phase) => _showPhaseDetails(phase),
            onControllerReady: (controller) => _ganttScrollController = controller,
          ),
        ),
      ],
    );
  }

  void _showPhaseDetails(GanttPhase phase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(phase.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('PO Number', phase.poNumber),
              _buildDetailRow('Phase', phase.name),
              _buildDetailRow('Status', phase.status),
              _buildDetailRow('Progress', '${phase.progress}%'),
              _buildDetailRow('Duration', '${phase.duration} days'),
              if (phase.start != null)
                _buildDetailRow('Start Date', _formatDate(phase.start!)),
              if (phase.end != null)
                _buildDetailRow('End Date', _formatDate(phase.end!)),
              if (phase.notes != null && phase.notes!.isNotEmpty)
                _buildDetailRow('Notes', phase.notes!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }
}