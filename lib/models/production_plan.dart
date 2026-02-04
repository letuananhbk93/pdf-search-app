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
      id: json['id'] ?? 0,
      poNumber: json['po_number']?.toString() ?? '',
      phaseName: json['phase_name']?.toString() ?? '',
      startDate: json['start_date'] != null 
          ? DateTime.tryParse(json['start_date'].toString()) 
          : null,
      endDate: json['end_date'] != null 
          ? DateTime.tryParse(json['end_date'].toString()) 
          : null,
      status: json['status']?.toString() ?? 'Not Started',
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at'].toString()) 
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

  int get duration {
    if (startDate == null || endDate == null) return 0;
    return endDate!.difference(startDate!).inDays + 1;
  }
}

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
      poNumber: json['po_number']?.toString() ?? '',
      projectStart: json['project_start'] != null 
          ? DateTime.tryParse(json['project_start'].toString()) 
          : null,
      projectEnd: json['project_end'] != null 
          ? DateTime.tryParse(json['project_end'].toString()) 
          : null,
      totalDuration: json['total_duration'] ?? 0,
      phases: (json['phases'] as List? ?? [])
          .map((e) => GanttPhase.fromJson(e ?? {}))
          .toList(),
    );
  }
}

class GanttPhase {
  final int id;
  final String name;
  final String poNumber;
  final DateTime? start;
  final DateTime? end;
  final int duration;
  final String status;
  final int progress;
  final String? notes;

  GanttPhase({
    required this.id,
    required this.name,
    required this.poNumber,
    this.start,
    this.end,
    required this.duration,
    required this.status,
    required this.progress,
    this.notes,
  });

  factory GanttPhase.fromJson(Map<String, dynamic> json) {
    return GanttPhase(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? json['phase_name']?.toString() ?? 'Unnamed Phase',
      poNumber: json['po_number']?.toString() ?? '',
      start: json['start'] != null 
          ? DateTime.tryParse(json['start'].toString()) 
          : (json['start_date'] != null 
              ? DateTime.tryParse(json['start_date'].toString()) 
              : null),
      end: json['end'] != null 
          ? DateTime.tryParse(json['end'].toString()) 
          : (json['end_date'] != null 
              ? DateTime.tryParse(json['end_date'].toString()) 
              : null),
      duration: json['duration'] ?? 0,
      status: json['status']?.toString() ?? 'Not Started',
      progress: json['progress'] ?? 0,
      notes: json['notes']?.toString(),
    );
  }
}

enum ViewMode { week, month }

// Response model for production plan with view modes
class ProductionPlanResponse {
  final String poNumber;
  final String viewMode;
  final String projectStart;
  final String projectEnd;
  final int totalDuration;
  final double totalDurationWeeks;
  final List<dynamic> phases; // WeekPhase or MonthGroup
  final int totalPhases;
  final int displayItems;

  ProductionPlanResponse({
    required this.poNumber,
    required this.viewMode,
    required this.projectStart,
    required this.projectEnd,
    required this.totalDuration,
    required this.totalDurationWeeks,
    required this.phases,
    required this.totalPhases,
    required this.displayItems,
  });

  factory ProductionPlanResponse.fromJson(Map<String, dynamic> json) {
    List<dynamic> phases = [];
    
    // Both week and month views now return the same phase structure
    // with different timeline fields
    phases = (json['phases'] as List? ?? [])
        .map((phase) => GanttPhaseExtended.fromJson(phase))
        .toList();

    return ProductionPlanResponse(
      poNumber: json['po_number'] ?? '',
      viewMode: json['view_mode'] ?? 'week',
      projectStart: json['project_start'] ?? '',
      projectEnd: json['project_end'] ?? '',
      totalDuration: json['total_duration'] ?? 0,
      totalDurationWeeks: (json['total_duration_weeks'] ?? 0).toDouble(),
      phases: phases,
      totalPhases: json['total_phases'] ?? 0,
      displayItems: json['display_items'] ?? 0,
    );
  }
}

// Unified phase model that handles both view modes
class GanttPhaseExtended {
  final int id;
  final String name;
  final DateTime? start;
  final DateTime? end;
  final int duration;
  final String status;
  final int progress;
  final String notes;
  final String poNumber;
  final String viewMode;
  
  // Week view specific fields
  final double? durationWeeks;
  final String? weekStart;
  final String? weekEnd;
  final int? weekNumber;
  final String? weekLabel;
  
  // Month view specific fields
  final String? timelineDescription;
  final String? startWeekInfo;
  final String? endWeekInfo;

  GanttPhaseExtended({
    required this.id,
    required this.name,
    this.start,
    this.end,
    required this.duration,
    required this.status,
    required this.progress,
    required this.notes,
    required this.poNumber,
    required this.viewMode,
    this.durationWeeks,
    this.weekStart,
    this.weekEnd,
    this.weekNumber,
    this.weekLabel,
    this.timelineDescription,
    this.startWeekInfo,
    this.endWeekInfo,
  });

  factory GanttPhaseExtended.fromJson(Map<String, dynamic> json) {
    return GanttPhaseExtended(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      start: _parseDate(json['start']),
      end: _parseDate(json['end']),
      duration: json['duration'] ?? 0,
      status: json['status'] ?? '',
      progress: json['progress'] ?? 0,
      notes: json['notes'] ?? '',
      poNumber: json['po_number'] ?? '',
      viewMode: json['view_mode'] ?? 'week',
      // Week view fields
      durationWeeks: json['duration_weeks']?.toDouble(),
      weekStart: json['week_start'],
      weekEnd: json['week_end'],
      weekNumber: json['week_number'],
      weekLabel: json['week_label'],
      // Month view fields
      timelineDescription: json['timeline_description'],
      startWeekInfo: json['start_week_info'],
      endWeekInfo: json['end_week_info'],
    );
  }
  
  // Convert to regular GanttPhase for chart compatibility
  GanttPhase toGanttPhase() {
    return GanttPhase(
      id: id,
      name: name,
      start: start,
      end: end,
      duration: duration,
      status: status,
      progress: progress,
      notes: notes,
      poNumber: poNumber,
    );
  }
}

// Helper function to parse dates
DateTime? _parseDate(dynamic dateStr) {
  if (dateStr == null || dateStr == '') return null;
  try {
    if (dateStr is String) {
      return DateTime.parse(dateStr);
    }
  } catch (e) {
    print('Error parsing date: $dateStr, Error: $e');
  }
  return null;
}