# Flutter Production Plan Gantt Chart Implementation Guide

## 🎯 Overview
Complete guide to implement the Production Plan Gantt chart in Flutter, consuming your FastAPI backend.

## 📦 Required Flutter Dependencies

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # HTTP & API
  http: ^1.1.0
  dio: ^5.3.2              # Alternative to http, better for APIs
  
  # State Management
  provider: ^6.1.1         # or riverpod/bloc - choose your preference
  
  # UI Components
  syncfusion_flutter_charts: ^23.2.7    # For Gantt charts
  # OR build custom with these:
  timeline_tile: ^2.0.0    # For timeline UI
  table_calendar: ^3.0.9   # For date selection
  
  # Date/Time
  intl: ^0.19.0           # Date formatting
  
  # Storage
  shared_preferences: ^2.2.2  # Cache data
  
  # Utils
  logger: ^2.0.2          # Logging
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

## 🏗️ Project Structure

```
lib/
├── models/
│   ├── production_plan.dart
│   ├── gantt_data.dart
│   └── api_response.dart
├── services/
│   ├── api_service.dart
│   └── production_service.dart
├── providers/
│   └── production_provider.dart
├── screens/
│   ├── production_plan_screen.dart
│   ├── gantt_chart_screen.dart
│   └── phase_edit_screen.dart
├── widgets/
│   ├── gantt_chart_widget.dart
│   ├── timeline_header.dart
│   ├── phase_bar.dart
│   └── project_selector.dart
└── utils/
    ├── date_utils.dart
    └── constants.dart
```

## 📊 Data Models

### 1. Production Plan Model
```dart
// models/production_plan.dart
class ProductionPlan {
  final int id;
  final String poNumber;
  final String phaseName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProductionPlan({
    required this.id,
    required this.poNumber,
    required this.phaseName,
    this.startDate,
    this.endDate,
    required this.status,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory ProductionPlan.fromJson(Map<String, dynamic> json) {
    return ProductionPlan(
      id: json['id'],
      poNumber: json['po_number'],
      phaseName: json['phase_name'],
      startDate: json['start_date'] != null 
          ? DateTime.parse(json['start_date']) 
          : null,
      endDate: json['end_date'] != null 
          ? DateTime.parse(json['end_date']) 
          : null,
      status: json['status'],
      notes: json['notes'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'po_number': poNumber,
      'phase_name': phaseName,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status,
      'notes': notes,
    };
  }
}
```

### 2. Gantt Data Model
```dart
// models/gantt_data.dart
class GanttData {
  final String poNumber;
  final DateTime? projectStart;
  final DateTime? projectEnd;
  final int totalDuration;
  final List<GanttPhase> phases;

  GanttData({
    required this.poNumber,
    this.projectStart,
    this.projectEnd,
    required this.totalDuration,
    required this.phases,
  });

  factory GanttData.fromJson(Map<String, dynamic> json) {
    return GanttData(
      poNumber: json['po_number'],
      projectStart: json['project_start'] != null 
          ? DateTime.parse(json['project_start']) 
          : null,
      projectEnd: json['project_end'] != null 
          ? DateTime.parse(json['project_end']) 
          : null,
      totalDuration: json['total_duration'],
      phases: (json['phases'] as List)
          .map((e) => GanttPhase.fromJson(e))
          .toList(),
    );
  }
}

class GanttPhase {
  final int id;
  final String name;
  final DateTime? start;
  final DateTime? end;
  final int duration;
  final String status;
  final int progress;
  final String? notes;

  GanttPhase({
    required this.id,
    required this.name,
    this.start,
    this.end,
    required this.duration,
    required this.status,
    required this.progress,
    this.notes,
  });

  factory GanttPhase.fromJson(Map<String, dynamic> json) {
    return GanttPhase(
      id: json['id'],
      name: json['name'],
      start: json['start'] != null ? DateTime.parse(json['start']) : null,
      end: json['end'] != null ? DateTime.parse(json['end']) : null,
      duration: json['duration'],
      status: json['status'],
      progress: json['progress'],
      notes: json['notes'],
    );
  }
}
```

## 🌐 API Service

### API Service Implementation
```dart
// services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/production_plan.dart';
import '../models/gantt_data.dart';

class ApiService {
  static const String baseUrl = 'YOUR_BACKEND_URL'; // Replace with your API URL
  
  // Get all projects
  static Future<List<String>> getProjects() async {
    final response = await http.get(
      Uri.parse('$baseUrl/production-plan/projects'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<String>.from(data['projects']);
    } else {
      throw Exception('Failed to load projects');
    }
  }
  
  // Get Gantt data for a specific project
  static Future<GanttData> getGanttData(String poNumber) async {
    final response = await http.get(
      Uri.parse('$baseUrl/production-plan/$poNumber/gantt'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return GanttData.fromJson(data);
    } else {
      throw Exception('Failed to load Gantt data');
    }
  }
  
  // Get project phases
  static Future<List<ProductionPlan>> getProjectPhases(String poNumber) async {
    final response = await http.get(
      Uri.parse('$baseUrl/production-plan/$poNumber'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['phases'] as List)
          .map((e) => ProductionPlan.fromJson(e))
          .toList();
    } else {
      throw Exception('Failed to load project phases');
    }
  }
  
  // Update phase
  static Future<bool> updatePhase(int phaseId, Map<String, dynamic> updateData, String changedBy) async {
    final response = await http.put(
      Uri.parse('$baseUrl/production-plan/$phaseId?changed_by=$changedBy'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(updateData),
    );
    
    return response.statusCode == 200;
  }
  
  // Create new phase
  static Future<bool> createPhase(Map<String, dynamic> phaseData, String createdBy) async {
    final response = await http.post(
      Uri.parse('$baseUrl/production-plan?created_by=$createdBy'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(phaseData),
    );
    
    return response.statusCode == 200;
  }
}
```

## 🎛️ State Management (Provider)

```dart
// providers/production_provider.dart
import 'package:flutter/material.dart';
import '../models/production_plan.dart';
import '../models/gantt_data.dart';
import '../services/api_service.dart';

enum ViewMode { day, week, month }

class ProductionProvider extends ChangeNotifier {
  List<String> _projects = [];
  String? _selectedProject;
  GanttData? _ganttData;
  List<ProductionPlan> _phases = [];
  ViewMode _viewMode = ViewMode.week;
  bool _isLoading = false;
  String? _error;
  
  // Getters
  List<String> get projects => _projects;
  String? get selectedProject => _selectedProject;
  GanttData? get ganttData => _ganttData;
  List<ProductionPlan> get phases => _phases;
  ViewMode get viewMode => _viewMode;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Load initial data
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _projects = await ApiService.getProjects();
      if (_projects.isNotEmpty) {
        _selectedProject = _projects.first;
        await loadGanttData(_selectedProject!);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Load Gantt data for selected project
  Future<void> loadGanttData(String poNumber) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _ganttData = await ApiService.getGanttData(poNumber);
      _phases = await ApiService.getProjectPhases(poNumber);
      _selectedProject = poNumber;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Change view mode
  void setViewMode(ViewMode mode) {
    _viewMode = mode;
    notifyListeners();
  }
  
  // Update phase
  Future<bool> updatePhase(int phaseId, Map<String, dynamic> updateData) async {
    try {
      bool success = await ApiService.updatePhase(phaseId, updateData, 'mobile_user');
      if (success && _selectedProject != null) {
        await loadGanttData(_selectedProject!); // Refresh data
      }
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
```

## 📱 Main Screen Implementation

### Production Plan Screen
```dart
// screens/production_plan_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/production_provider.dart';
import '../widgets/gantt_chart_widget.dart';
import '../widgets/project_selector.dart';

class ProductionPlanScreen extends StatefulWidget {
  @override
  _ProductionPlanScreenState createState() => _ProductionPlanScreenState();
}

class _ProductionPlanScreenState extends State<ProductionPlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductionProvider>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Production Plan'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          // Project Selector
          Consumer<ProductionProvider>(
            builder: (context, provider, child) {
              return ProjectSelector(
                projects: provider.projects,
                selectedProject: provider.selectedProject,
                onProjectChanged: (project) {
                  if (project != null) {
                    provider.loadGanttData(project);
                  }
                },
              );
            },
          ),
          // View Mode Toggle
          Consumer<ProductionProvider>(
            builder: (context, provider, child) {
              return PopupMenuButton<ViewMode>(
                icon: Icon(Icons.view_module),
                onSelected: (mode) => provider.setViewMode(mode),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: ViewMode.day,
                    child: Text('Day View'),
                  ),
                  PopupMenuItem(
                    value: ViewMode.week,
                    child: Text('Week View'),
                  ),
                  PopupMenuItem(
                    value: ViewMode.month,
                    child: Text('Month View'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<ProductionProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 48, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Error: ${provider.error}'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.initialize(),
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          if (provider.ganttData == null) {
            return Center(
              child: Text('No data available'),
            );
          }
          
          return Column(
            children: [
              // Project Info Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.selectedProject ?? '',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (provider.ganttData != null) ...[
                      SizedBox(height: 4),
                      Text(
                        'Duration: ${provider.ganttData!.totalDuration} days',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      Text(
                        'Phases: ${provider.ganttData!.phases.length}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
              // Gantt Chart
              Expanded(
                child: GanttChartWidget(
                  ganttData: provider.ganttData!,
                  viewMode: provider.viewMode,
                  onPhaseEdit: (phase) => _showPhaseEditDialog(context, phase),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPhaseDialog(context),
        child: Icon(Icons.add),
        tooltip: 'Add Phase',
      ),
    );
  }
  
  void _showPhaseEditDialog(BuildContext context, GanttPhase phase) {
    // Implement phase edit dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${phase.name}'),
        content: Text('Edit functionality - implement form here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement save functionality
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _showAddPhaseDialog(BuildContext context) {
    // Implement add phase dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Phase'),
        content: Text('Add phase functionality - implement form here'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement create functionality
              Navigator.pop(context);
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }
}
```

## 🎨 Gantt Chart Widget

### Custom Gantt Chart Implementation
```dart
// widgets/gantt_chart_widget.dart
import 'package:flutter/material.dart';
import '../models/gantt_data.dart';
import '../providers/production_provider.dart';

class GanttChartWidget extends StatefulWidget {
  final GanttData ganttData;
  final ViewMode viewMode;
  final Function(GanttPhase) onPhaseEdit;

  const GanttChartWidget({
    Key? key,
    required this.ganttData,
    required this.viewMode,
    required this.onPhaseEdit,
  }) : super(key: key);

  @override
  _GanttChartWidgetState createState() => _GanttChartWidgetState();
}

class _GanttChartWidgetState extends State<GanttChartWidget> {
  final ScrollController _scrollController = ScrollController();
  final double _phaseRowHeight = 60.0;
  final double _leftColumnWidth = 150.0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Fixed left column (Phase names)
        Container(
          width: _leftColumnWidth,
          child: Column(
            children: [
              // Header
              Container(
                height: 50,
                color: Colors.blue[100],
                child: Center(
                  child: Text(
                    'Phases',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              // Phase names
              Expanded(
                child: ListView.builder(
                  itemCount: widget.ganttData.phases.length,
                  itemBuilder: (context, index) {
                    final phase = widget.ganttData.phases[index];
                    return Container(
                      height: _phaseRowHeight,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              phase.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 2),
                            Row(
                              children: [
                                _getStatusIcon(phase.status),
                                SizedBox(width: 4),
                                Text(
                                  '${phase.progress}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
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
        ),
        // Scrollable timeline
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [
                // Timeline header
                _buildTimelineHeader(),
                // Gantt bars
                Expanded(
                  child: Container(
                    width: _calculateTimelineWidth(),
                    child: ListView.builder(
                      itemCount: widget.ganttData.phases.length,
                      itemBuilder: (context, index) {
                        final phase = widget.ganttData.phases[index];
                        return GestureDetector(
                          onTap: () => widget.onPhaseEdit(phase),
                          child: Container(
                            height: _phaseRowHeight,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey[300]!),
                              ),
                            ),
                            child: _buildPhaseBar(phase),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineHeader() {
    // Calculate date range and build header
    final projectStart = widget.ganttData.projectStart;
    final projectEnd = widget.ganttData.projectEnd;
    
    if (projectStart == null || projectEnd == null) {
      return Container(height: 50, color: Colors.blue[100]);
    }
    
    return Container(
      height: 50,
      color: Colors.blue[100],
      child: Row(
        children: _buildTimelineHeaderItems(projectStart, projectEnd),
      ),
    );
  }
  
  List<Widget> _buildTimelineHeaderItems(DateTime start, DateTime end) {
    List<Widget> items = [];
    DateTime current = DateTime(start.year, start.month, start.day);
    
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      items.add(
        Container(
          width: _getDayWidth(),
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey[400]!)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${current.day}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              Text(
                _getMonthAbbreviation(current.month),
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
      
      current = current.add(Duration(days: 1));
    }
    
    return items;
  }
  
  Widget _buildPhaseBar(GanttPhase phase) {
    if (phase.start == null || phase.end == null || widget.ganttData.projectStart == null) {
      return Container(); // Empty if no dates
    }
    
    final projectStart = widget.ganttData.projectStart!;
    final startOffset = phase.start!.difference(projectStart).inDays;
    final duration = phase.duration;
    
    return Stack(
      children: [
        // Background grid
        Positioned.fill(
          child: Row(
            children: _buildGridLines(),
          ),
        ),
        // Phase bar
        Positioned(
          left: startOffset * _getDayWidth(),
          top: 15,
          child: Container(
            width: duration * _getDayWidth(),
            height: 30,
            decoration: BoxDecoration(
              color: _getStatusColor(phase.status),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  // Progress bar
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: (duration * _getDayWidth()) * (phase.progress / 100),
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
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          phase.name,
                          style: TextStyle(
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
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  List<Widget> _buildGridLines() {
    final totalDays = widget.ganttData.totalDuration;
    List<Widget> lines = [];
    
    for (int i = 0; i < totalDays; i++) {
      lines.add(
        Container(
          width: _getDayWidth(),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Colors.grey[300]!,
                width: 0.5,
              ),
            ),
          ),
        ),
      );
    }
    
    return lines;
  }
  
  double _getDayWidth() {
    switch (widget.viewMode) {
      case ViewMode.day:
        return 40.0;
      case ViewMode.week:
        return 20.0;
      case ViewMode.month:
        return 10.0;
    }
  }
  
  double _calculateTimelineWidth() {
    return widget.ganttData.totalDuration * _getDayWidth();
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'In Progress':
        return Colors.orange;
      case 'Delayed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  Widget _getStatusIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icon(Icons.check_circle, color: Colors.green, size: 12);
      case 'In Progress':
        return Icon(Icons.access_time, color: Colors.orange, size: 12);
      case 'Delayed':
        return Icon(Icons.warning, color: Colors.red, size: 12);
      default:
        return Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 12);
    }
  }
  
  String _getMonthAbbreviation(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
```

## 🎯 Key Implementation Tips

### 1. **Performance Optimization**
```dart
// Use ListView.builder for large datasets
// Cache network responses locally
// Implement pull-to-refresh
```

### 2. **Responsive Design**
```dart
// Adjust Gantt bar width based on screen size
// Use MediaQuery for responsive layouts
// Support both portrait and landscape
```

### 3. **Error Handling**
```dart
// Implement retry mechanisms
// Show user-friendly error messages
// Cache data for offline viewing
```

### 4. **User Experience**
```dart
// Add loading indicators
// Implement smooth scrolling
// Provide visual feedback for interactions
```

## 🚀 Next Implementation Steps

1. **Setup Project**: Create Flutter project with dependencies
2. **Implement Models**: Start with data models and API service
3. **Build Basic UI**: Create main screen and basic layout
4. **Add Gantt Chart**: Implement custom Gantt widget
5. **Add Interactions**: Edit/add phase functionality
6. **Polish UI**: Colors, animations, responsiveness
7. **Test & Debug**: Test with real data from your backend

## 💡 Advanced Features to Add Later

- **Drag & Drop**: Reschedule phases by dragging bars
- **Zoom**: Pinch to zoom timeline view
- **Filters**: Filter by status, date range
- **Notifications**: Push notifications for deadlines
- **Export**: Save Gantt chart as image/PDF
- **Offline Mode**: Cache data and sync when online

This guide gives you everything needed to build a professional Gantt chart interface that works seamlessly with your Production Plan backend! 🎉