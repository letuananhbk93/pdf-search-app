import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../services/timeline_service.dart';
import '../widgets/timeline_widgets.dart';

/// Shows the breadcrumb, the "Last updated" line and the screen content for one loaded response.
class TimelineBody extends StatelessWidget {
  const TimelineBody({
    super.key,
    required this.path,
    required this.future,
    required this.onRetry,
    required this.builder,
  });

  final List<String> path;
  final Future<Map<String, dynamic>> future;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, Map<String, dynamic> data) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final Widget content;
        if (snapshot.hasError) {
          content = Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text('${snapshot.error}', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          );
        } else if (data == null) {
          content = const Center(child: CircularProgressIndicator());
        } else {
          content = builder(context, data);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TimelineBreadcrumb(path: path),
            TimelineLastUpdated(lastUpdated: data?['last_updated'] as String?),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

/// Screen 2: PO cards for one year.
class TimelinePoScreen extends StatefulWidget {
  const TimelinePoScreen({super.key, required this.year, required this.path});

  final int year;
  final List<String> path;

  @override
  State<TimelinePoScreen> createState() => _TimelinePoScreenState();
}

class _TimelinePoScreenState extends State<TimelinePoScreen> {
  final TimelineService _service = TimelineService();
  late Future<Map<String, dynamic>> _future = _service.fetchPos(widget.year);

  void _retry() => setState(() => _future = _service.fetchPos(widget.year));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildTimelineAppBar(),
      body: TimelineBody(
        path: widget.path,
        future: _future,
        onRetry: _retry,
        builder: (context, data) {
          final pos = List<Map<String, dynamic>>.from(data['pos'] as List);
          if (pos.isEmpty) {
            return Center(child: Text('No POs for ${widget.year}', style: const TextStyle(color: Colors.grey)));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisExtent: 150,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: pos.length,
            itemBuilder: (context, index) {
              final po = pos[index];
              final poLabel = 'PO${po['po_no']}';
              return TimelineProgressCard(
                title: poLabel,
                pct: (po['pct'] as num).toDouble(),
                subtitle: 'Finished: ${(po['finished_qty'] as num).round()}/${(po['qty'] as num).round()} pcs',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TimelineSupplierScreen(
                      poKey: po['po_key'] as String,
                      path: [...widget.path, poLabel],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Screen 3: supplier cards for one PO.
class TimelineSupplierScreen extends StatefulWidget {
  const TimelineSupplierScreen({super.key, required this.poKey, required this.path});

  final String poKey;
  final List<String> path;

  @override
  State<TimelineSupplierScreen> createState() => _TimelineSupplierScreenState();
}

class _TimelineSupplierScreenState extends State<TimelineSupplierScreen> {
  final TimelineService _service = TimelineService();
  late Future<Map<String, dynamic>> _future = _service.fetchSuppliers(widget.poKey);

  void _retry() => setState(() => _future = _service.fetchSuppliers(widget.poKey));

  /// Each supplier's counts. A sheet with fewer than 3 blocks has no schedule data and is skipped (counts null).
  Future<List<SupplierSchedule>> _loadSchedules(List<Map<String, dynamic>> suppliers) async {
    final details = await Future.wait([for (final s in suppliers) _service.fetchSupplier(s['supplier_id'] as int)]);
    final today = DateTime.now();
    return [
      for (var i = 0; i < suppliers.length; i++) _scheduleOf(suppliers[i]['name'] as String, details[i], today),
    ];
  }

  static SupplierSchedule _scheduleOf(String name, Map<String, dynamic> detail, DateTime today) {
    final blocks = List<Map<String, dynamic>>.from(detail['blocks'] as List? ?? const []);
    if (blocks.length < 3) return SupplierSchedule(name, null);
    final plan = PlanColours.fromData(blocks, List<String>.from(detail['headers'] as List), today);
    final products = List<Map<String, dynamic>>.from(detail['products'] as List);
    return SupplierSchedule(name, ScheduleCounts.ofProducts(plan, products));
  }

  void _showPoDashboard(BuildContext context, List<Map<String, dynamic>> suppliers) {
    final future = _loadSchedules(suppliers);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('OVERVIEW - ${widget.poKey}', style: const TextStyle(color: kTimelineBordeaux)),
        content: SizedBox(
          width: dashboardDialogWidth(dialogContext, 640),
          child: FutureBuilder<List<SupplierSchedule>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
              }
              final schedules = snapshot.data;
              if (schedules == null) return const Center(child: CircularProgressIndicator());
              final scheduled = schedules.where((schedule) => schedule.counts != null).toList();
              final total = ScheduleCounts();
              for (final schedule in scheduled) {
                total.add(schedule.counts!);
              }
              final skipped = schedules.length - scheduled.length;
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScheduleSummary(counts: total),
                    const SizedBox(height: 12),
                    if (scheduled.isNotEmpty) ScheduleTable(rows: scheduled),
                    const SizedBox(height: 4),
                    if (skipped > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          '$skipped ${skipped == 1 ? 'supplier' : 'suppliers'} skipped (no schedule data)',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildTimelineAppBar(),
      body: TimelineBody(
        path: widget.path,
        future: _future,
        onRetry: _retry,
        builder: (context, data) {
          final suppliers = List<Map<String, dynamic>>.from(data['suppliers'] as List);
          if (suppliers.isEmpty) {
            return const Center(child: Text('No suppliers in this PO', style: TextStyle(color: Colors.grey)));
          }
          return Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: kTimelineBordeaux, foregroundColor: Colors.white),
                    onPressed: () => _showPoDashboard(context, suppliers),
                    child: const Text('OVERVIEW'),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 260,
                    mainAxisExtent: 150,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: suppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = suppliers[index];
                    final name = supplier['name'] as String;
                    return TimelineProgressCard(
                      title: name,
                      pct: (supplier['pct'] as num).toDouble(),
                      subtitle: '${supplier['product_count']} products',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TimelineTableScreen(
                            supplierId: supplier['supplier_id'] as int,
                            path: [...widget.path, name],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One supplier's schedule counts for the PO dashboard. counts is null when the sheet has no schedule data.
class SupplierSchedule {
  const SupplierSchedule(this.name, this.counts);

  final String name;
  final ScheduleCounts? counts;
}

/// Screen 4: the supplier's timeline table; completed stage cells are tinted yellow.
/// Screen 1 shows block 1 and the NOTES column. FOR MANAGER (forManager: true) shows blocks 2 and 3 with the
/// colours from the sheet. Tap a header to sort by it, double tap to hide it, right-click or hold a header for
/// 2 seconds to unhide.
class TimelineTableScreen extends StatefulWidget {
  const TimelineTableScreen({super.key, required this.supplierId, required this.path, this.forManager = false});

  final int supplierId;
  final List<String> path;
  final bool forManager;

  @override
  State<TimelineTableScreen> createState() => _TimelineTableScreenState();
}

class _TimelineTableScreenState extends State<TimelineTableScreen> {
  static const double _columnWidth = 140;
  static const double _narrowColumnWidth = _columnWidth / 3;
  static const double _progressWidth = 100;
  static const double _rowHeight = 44;
  static const double _headerHeight = 56;
  static const Duration _holdDuration = Duration(seconds: 2);
  static const _narrowHeaders = {'NO', 'QTY'};
  static final _zebraColor = Colors.grey.shade100;
  static final _block3Colour = Colors.lightBlue.shade100;
  static final _weekPattern = RegExp(r'^(\d+)(\.0+)?$');

  final TimelineService _service = TimelineService();
  late Future<Map<String, dynamic>> _future = _service.fetchSupplier(widget.supplierId);
  final ScrollController _horizontalScroll = ScrollController();
  final ScrollController _verticalScroll = ScrollController();

  // Sorted column (original index), or null to keep the backend order
  int? _sortColumn;
  // Hidden columns: original index -> header label
  final Map<int, String> _hiddenColumns = {};
  // Product rows (index in the backend list) shown at full text height
  final Set<int> _expandedRows = {};
  // FOR MANAGER hides these by default; the Columns dialog shows them. Not kept between visits (new screen state).
  static const _defaultHiddenLabels = {'CUSTOMER', 'IMAGE'};
  final Set<int> _shownByUser = {};
  Timer? _holdTimer;
  // Set when a hold opened the restore dialog, so the tap that ends the hold does not also sort
  bool _holdFired = false;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _horizontalScroll.dispose();
    _verticalScroll.dispose();
    super.dispose();
  }

  void _retry() => setState(() => _future = _service.fetchSupplier(widget.supplierId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.forManager
          ? buildTimelineAppBar(
              automaticallyImplyLeading: false,
              actions: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  label: const Text('Back', style: TextStyle(color: Colors.white)),
                ),
              ],
            )
          : buildTimelineAppBar(),
      body: TimelineBody(
        path: widget.path,
        future: _future,
        onRetry: _retry,
        builder: (context, data) {
          final headers = List<String>.from(data['headers'] as List);
          final stageColumns = List<int>.from(data['stage_columns'] as List);
          final products = List<Map<String, dynamic>>.from(data['products'] as List);
          final blocks = List<Map<String, dynamic>>.from(data['blocks'] as List? ?? const []);
          if (products.isEmpty) {
            return const Center(child: Text('No products', style: TextStyle(color: Colors.grey)));
          }

          // Column index -> position in stage_done (only stage columns have one)
          final stagePosition = {for (var i = 0; i < stageColumns.length; i++) stageColumns[i]: i};

          // Column index -> block number (0 = block 1). Columns before the first block (NO, PRODUCT, IMAGE...)
          // belong to no block and show on both screens.
          final blockOf = <int, int>{};
          for (var b = 0; b < blocks.length; b++) {
            for (final column in List<int>.from(blocks[b]['columns'] as List)) {
              blockOf[column] = b;
            }
          }
          final noteColumn = headers.indexWhere((header) => header.toUpperCase() == 'NOTES');
          bool shownHere(int column) {
            final block = blockOf[column];
            if (block == null) return true;
            return widget.forManager ? block >= 1 : block == 0 || column == noteColumn;
          }
          final showManagerButton = !widget.forManager && blocks.length >= 2;
          final planColours = widget.forManager && blocks.length >= 2
              ? PlanColours.fromData(blocks, headers, DateTime.now())
              : null;
          // FOR MANAGER: the stage columns of blocks 2 and 3 hold week numbers, shown as W6 (Week 6)
          final weekStages = {
            for (var b = 1; b < blocks.length; b++) ...List<int>.from(blocks[b]['stage_columns'] as List),
          };

          // Progress is appended after the backend columns; swap it with IMAGE so it sits where IMAGE was.
          // FOR MANAGER: Progress sits just left of block 2's first stage column instead.
          final progressColumn = headers.length;
          final imageColumn = headers.indexWhere((header) => header.toUpperCase() == 'IMAGE');
          final actualStages = widget.forManager && blocks.length >= 2
              ? List<int>.from(blocks[1]['stage_columns'] as List)
              : const <int>[];
          final actualStart = actualStages.isEmpty ? -1 : actualStages.first;
          final columnOrder = List<int>.generate(headers.length + 1, (i) => i);
          if (widget.forManager) {
            columnOrder.remove(progressColumn);
            columnOrder.insert(actualStart < 0 ? headers.length : columnOrder.indexOf(actualStart), progressColumn);
          } else if (imageColumn >= 0) {
            columnOrder[imageColumn] = progressColumn;
            columnOrder[progressColumn] = imageColumn;
          }
          // Columns the FOR MANAGER view hides by default (CUSTOMER, IMAGE) unless the user shows them
          final defaultHiddenColumns = widget.forManager
              ? [for (var i = 0; i < headers.length; i++) if (_defaultHiddenLabels.contains(headers[i].trim().toUpperCase())) i]
              : const <int>[];

          final columns = <_TableColumn>[];
          for (final column in columnOrder) {
            if (_hiddenColumns.containsKey(column) || !shownHere(column) || _hiddenByDefault(column, headers)) continue;
            if (column == progressColumn) {
              columns.add(_TableColumn(index: column, label: 'Progress', width: _progressWidth, isProgress: true));
            } else {
              final label = headers[column];
              final width = _narrowHeaders.contains(label.toUpperCase()) ? _narrowColumnWidth : _columnWidth;
              // Block 3 is one fixed colour on the FOR MANAGER view, so it stands out from block 2
              final fixed = widget.forManager && (blockOf[column] ?? 0) >= 2 ? _block3Colour : null;
              final weekStage = widget.forManager && weekStages.contains(column);
              columns.add(_TableColumn(index: column, label: label, width: width, fixedBackground: fixed, weekStage: weekStage));
            }
          }

          final sortColumn = _sortColumn;
          final productOrder = sortColumn == null
              ? [for (var i = 0; i < products.length; i++) if (!_isNote(products[i])) i]
              : _sortOrder(products, sortColumn, progressColumn);
          final order = _withNotes(productOrder, products);
          final tableWidth = columns.fold<double>(0, (total, column) => total + column.width);

          // Zebra striping on every other product row, only across the columns from NO to Progress (sheet view)
          final productRows = [for (final index in order) if (!_isNote(products[index])) index];
          final zebraRows = {for (var i = 1; i < productRows.length; i += 2) productRows[i]};
          final noPosition = columns.indexWhere((column) => _isNoHeader(column.label));
          final progressPosition = columns.indexWhere((column) => column.isProgress);
          final zebraColumns = {
            for (var c = noPosition < 0 ? 0 : noPosition; c <= (progressPosition < 0 ? columns.length - 1 : progressPosition); c++) c,
          };

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        widget.forManager
                            ? 'Cells show the colours from the sheet. Block 3 is light blue. '
                                'Tap a header to sort (tap again to undo), double tap to hide, '
                                'right-click or hold a header 2 seconds to unhide. Tap a row to show its full text.'
                            : 'Yellow cells: stage completed. Blue rows are notes (no QTY), not products. '
                                'Tap a header to sort (tap again to undo), double tap to hide, '
                                'right-click or hold a header 2 seconds to unhide. Tap a row to show its full text.',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ),
                  if (showManagerButton)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: kTimelineBordeaux, foregroundColor: Colors.white),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TimelineTableScreen(
                              supplierId: widget.supplierId,
                              path: widget.path,
                              forManager: true,
                            ),
                          ),
                        ),
                        child: const Text('FOR MANAGER'),
                      ),
                    ),
                  if (widget.forManager && planColours != null && planColours.plan.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: kTimelineBordeaux, foregroundColor: Colors.white),
                        onPressed: () => _showSupplierDashboard(context, planColours, products),
                        child: const Text('OVERVIEW'),
                      ),
                    ),
                  if (defaultHiddenColumns.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                      child: OutlinedButton.icon(
                        onPressed: () => _showColumnsDialog(context, defaultHiddenColumns, headers),
                        icon: const Icon(Icons.view_column, size: 18),
                        label: const Text('Columns'),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: ScrollConfiguration(
                  behavior: const TimelineScrollBehavior(),
                  child: Scrollbar(
                    controller: _verticalScroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalScroll,
                      child: Scrollbar(
                        controller: _horizontalScroll,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _horizontalScroll,
                          scrollDirection: Axis.horizontal,
                          child: Column(
                            children: [
                              _headerRow(columns),
                              for (final index in order)
                                if (_isNote(products[index]))
                                  _noteRow(products[index], tableWidth)
                                else
                                  _productRow(index, products[index], columns, stagePosition, zebraRows.contains(index), zebraColumns, planColours),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static bool _isNote(Map<String, dynamic> product) => product['is_comment'] == true;

  /// Note rows stay with the product that follows them in the backend order, so sorting does not scatter them.
  /// Notes after the last product stay at the end.
  List<int> _withNotes(List<int> productOrder, List<Map<String, dynamic>> products) {
    final notesBefore = <int, List<int>>{};
    var pending = <int>[];
    for (var i = 0; i < products.length; i++) {
      if (_isNote(products[i])) {
        pending.add(i);
      } else {
        notesBefore[i] = pending;
        pending = <int>[];
      }
    }
    final order = <int>[];
    for (final index in productOrder) {
      order.addAll(notesBefore[index] ?? const <int>[]);
      order.add(index);
    }
    order.addAll(pending);
    return order;
  }

  /// A note across the whole table: bigger and bold, so the rows below it are easy to tell apart.
  Widget _noteRow(Map<String, dynamic> note, double width) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: _rowHeight + 16),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        border: Border(
          top: BorderSide(color: Colors.blue.shade100),
          bottom: BorderSide(color: Colors.blue.shade100),
          left: BorderSide(color: Colors.blue.shade800, width: 6),
        ),
      ),
      child: Text(
        note['product'] as String,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
      ),
    );
  }

  /// Row order for a sort on one column: numbers, percents and dates by size, text A to Z, blanks last.
  /// Note rows are not sorted; see _withNotes.
  List<int> _sortOrder(List<Map<String, dynamic>> products, int column, int progressColumn) {
    final values = [
      for (final product in products)
        column == progressColumn ? '${product['pct']}' : (product['cells'] as List)[column].toString(),
    ];
    final productRows = [for (var i = 0; i < products.length; i++) if (!_isNote(products[i])) i];
    final present = [for (final i in productRows) if (values[i].trim().isNotEmpty) i];
    final blanks = [for (final i in productRows) if (values[i].trim().isEmpty) i];

    final numeric = present.every((i) => _parseNumber(values[i]) != null);
    final dated = !numeric && present.every((i) => _parseDate(values[i]) != null);
    int compare(int a, int b) {
      if (numeric) return _parseNumber(values[a])!.compareTo(_parseNumber(values[b])!);
      if (dated) return _parseDate(values[a])!.compareTo(_parseDate(values[b])!);
      return values[a].trim().toUpperCase().compareTo(values[b].trim().toUpperCase());
    }

    present.sort((a, b) {
      final result = compare(a, b);
      return result != 0 ? result : a.compareTo(b);
    });
    return [...present, ...blanks];
  }

  static final _numberPattern = RegExp(r'^-?\d+(\.\d+)?$');
  static final _datePattern = RegExp(r'^(\d{1,2})/(\d{1,2})(?:/(\d{2}|\d{4}))?$');

  static double? _parseNumber(String text) {
    final cleaned = text.replaceAll(RegExp(r'[,%\s]'), '');
    return _numberPattern.hasMatch(cleaned) ? double.parse(cleaned) : null;
  }

  /// dd/mm or dd/mm/yy(yy) as a sortable yyyymmdd number (year 0 when missing).
  static int? _parseDate(String text) {
    final match = _datePattern.firstMatch(text.trim());
    if (match == null) return null;
    var year = int.parse(match.group(3) ?? '0');
    if (year > 0 && year < 100) year += 2000;
    return year * 10000 + int.parse(match.group(2)!) * 100 + int.parse(match.group(1)!);
  }

  bool _hiddenByDefault(int column, List<String> headers) {
    return widget.forManager &&
        column < headers.length &&
        _defaultHiddenLabels.contains(headers[column].trim().toUpperCase()) &&
        !_shownByUser.contains(column);
  }

  static bool _isNoHeader(String label) => label.trim().toUpperCase().replaceFirst(RegExp(r'\.$'), '') == 'NO';

  void _showColumnsDialog(BuildContext context, List<int> columns, List<String> headers) {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Columns'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final column in columns)
                CheckboxListTile(
                  title: Text(headers[column]),
                  value: _shownByUser.contains(column),
                  onChanged: (checked) {
                    setDialogState(() {});
                    setState(() => checked == true ? _shownByUser.add(column) : _shownByUser.remove(column));
                  },
                ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
        ),
      ),
    );
  }

  void _showSupplierDashboard(BuildContext context, PlanColours plan, List<Map<String, dynamic>> products) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('OVERVIEW - ${widget.path.last}', style: const TextStyle(color: kTimelineBordeaux)),
        content: SizedBox(width: dashboardDialogWidth(dialogContext, 360), child: ScheduleSummary(counts: ScheduleCounts.ofProducts(plan, products))),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  void _hideColumn(_TableColumn column) {
    setState(() {
      _hiddenColumns[column.index] = column.label;
      if (_sortColumn == column.index) _sortColumn = null;
    });
  }

  Future<void> _showRestoreDialog() async {
    final restore = await showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) {
        final selected = <int>{};
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Select Unhidden columns'),
            content: _hiddenColumns.isEmpty
                ? const Text('No hidden columns')
                : SizedBox(
                    width: 300,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in _hiddenColumns.entries)
                          CheckboxListTile(
                            title: Text(entry.value),
                            value: selected.contains(entry.key),
                            onChanged: (checked) {
                              setDialogState(() {
                                if (checked == true) {
                                  selected.add(entry.key);
                                } else {
                                  selected.remove(entry.key);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(dialogContext, selected), child: const Text('OK')),
            ],
          ),
        );
      },
    );
    if (restore == null || restore.isEmpty) return;
    setState(() => _hiddenColumns.removeWhere((index, _) => restore.contains(index)));
  }

  Widget _headerRow(List<_TableColumn> columns) {
    return Listener(
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse) {
          if (event.buttons == kSecondaryMouseButton) _showRestoreDialog();
          return;
        }
        _holdFired = false;
        _holdTimer?.cancel();
        _holdTimer = Timer(_holdDuration, () {
          _holdFired = true;
          if (mounted) _showRestoreDialog();
        });
      },
      onPointerUp: (_) => _holdTimer?.cancel(),
      onPointerCancel: (_) => _holdTimer?.cancel(),
      child: Row(
        children: [
          for (final column in columns) _headerCell(column, canHide: columns.length > 1),
        ],
      ),
    );
  }

  Widget _headerCell(_TableColumn column, {required bool canHide}) {
    final sorted = _sortColumn == column.index;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_holdFired) return;
        setState(() => _sortColumn = _sortColumn == column.index ? null : column.index);
      },
      onDoubleTap: canHide ? () => _hideColumn(column) : null,
      child: Container(
        width: column.width,
        height: _headerHeight,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: _paddingFor(column.width)),
        color: kTimelineBordeaux.withValues(alpha: 0.1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                column.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (sorted) const Icon(Icons.arrow_upward, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _productRow(
    int index,
    Map<String, dynamic> product,
    List<_TableColumn> columns,
    Map<int, int> stagePosition,
    bool zebra,
    Set<int> zebraColumns,
    PlanColours? planColours,
  ) {
    final cells = List<String>.from(product['cells'] as List);
    final stageDone = List<bool>.from(product['stage_done'] as List);
    final expanded = _expandedRows.contains(index);
    final row = Row(
      crossAxisAlignment: expanded ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
      children: [
        for (var c = 0; c < columns.length; c++)
          columns[c].isProgress
              ? _progressCell((product['pct'] as num).toDouble(), columns[c].width, background: zebra && zebraColumns.contains(c) ? _zebraColor : null)
              : _textCell(
                  columns[c].weekStage ? _weekLabel(cells[columns[c].index]) : cells[columns[c].index],
                  width: columns[c].width,
                  expanded: expanded,
                  background: _cellBackground(columns[c], planColours?.colourFor(cells, columns[c].index), product,
                      stagePosition, stageDone, zebra && zebraColumns.contains(c)),
                ),
      ],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => expanded ? _expandedRows.remove(index) : _expandedRows.add(index)),
      // Expanded rows are as tall as their tallest cell, so the full text shows
      child: expanded ? IntrinsicHeight(child: row) : row,
    );
  }

  /// FOR MANAGER: block 3 fixed colour, block 2 stage colour from the plan rules. Sheet view: yellow when the stage
  /// is done, else zebra.
  Color? _cellBackground(_TableColumn column, Color? planColour, Map<String, dynamic> product,
      Map<int, int> stagePosition, List<bool> stageDone, bool zebraCell) {
    if (widget.forManager) return column.fixedBackground ?? planColour ?? (zebraCell ? _zebraColor : null);
    final position = stagePosition[column.index];
    if (position != null && stageDone[position]) return const Color(0xFFFFFF00);
    return zebraCell ? _zebraColor : null;
  }

  /// A week number as 'W6'. Other text is unchanged.
  String _weekLabel(String text) {
    final match = _weekPattern.firstMatch(text.trim());
    return match == null ? text : 'W${match.group(1)}';
  }

  double _paddingFor(double width) => width == _narrowColumnWidth ? 4 : 12;

  Widget _textCell(String text, {required double width, required bool expanded, Color? background}) {
    return Container(
      width: width,
      height: expanded ? null : _rowHeight,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: _paddingFor(width), vertical: expanded ? 8 : 0),
      color: background,
      child: Text(text, maxLines: expanded ? null : 2, overflow: expanded ? null : TextOverflow.ellipsis),
    );
  }

  Widget _progressCell(double pct, double width, {Color? background}) {
    final color = timelineProgressColor(pct);
    return Container(
      width: width,
      height: _rowHeight,
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${pct.round()}%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: Colors.grey.shade200,
            ),
          ],
        ),
      ),
    );
  }
}

/// FOR MANAGER colours. Block 2 (actual) is compared with block 3 (planning), stage by stage, in the same row.
/// Block 2 stage cells only; the first matching rule decides the colour.
class PlanColours {
  const PlanColours({
    required this.actual,
    required this.plan,
    required this.rawCarcass,
    required this.orderDate,
    required this.currentWeek,
    this.finalQcStage,
  });

  static const green = Color(0xFF00B050);
  static const orange = Color(0xFFFFC000);
  static const red = Color(0xFFFF0000);

  /// Block 2 stage columns, and block 3 stage columns in the same order (pairs by position)
  final List<int> actual;
  final List<int> plan;
  final int? rawCarcass; // block 2 RAW CARCASS column: AVAILABLE is green
  final int? orderDate; // ORDER DATE * column: week the order was placed
  final int currentWeek; // ISO week of today
  final int? finalQcStage; // index into the block 1 stage list (stage_done) of FINAL QC; yellow = finished

  /// Built from the backend blocks (block 2 = actual, block 3 = planning).
  factory PlanColours.fromData(List<Map<String, dynamic>> blocks, List<String> headers, DateTime today) {
    final actual = List<int>.from(blocks[1]['stage_columns'] as List);
    final plan = blocks.length >= 3 ? List<int>.from(blocks[2]['stage_columns'] as List) : <int>[];
    final rawIndex = actual.indexWhere((column) => headers[column].toUpperCase() == 'RAW CARCASS');
    final orderIndex = headers.indexWhere((header) => header.toUpperCase() == 'ORDER DATE *');
    final finalIndex = List<int>.from(blocks[0]['stage_columns'] as List)
        .indexWhere((column) => headers[column].toUpperCase().startsWith('FINAL QC'));
    return PlanColours(
      actual: actual,
      plan: plan,
      rawCarcass: rawIndex < 0 ? null : actual[rawIndex],
      orderDate: orderIndex < 0 ? null : orderIndex,
      currentWeek: isoWeekOf(today),
      finalQcStage: finalIndex < 0 ? null : finalIndex,
    );
  }

  /// Status of an order (row): the colour of its rightmost block 2 stage cell that has one. Null when none does.
  Color? statusOf(List<String> cells) {
    for (final column in actual.reversed) {
      final colour = colourFor(cells, column);
      if (colour != null) return colour;
    }
    return null;
  }

  /// Colour of one cell (null = no colour). cells is the row's text per column.
  Color? colourFor(List<String> cells, int column) {
    final pair = actual.indexOf(column);
    if (pair < 0 || pair >= plan.length) return null;
    final actualText = cells[column].trim();
    final planText = cells[plan[pair]].trim();
    if (column == rawCarcass && actualText.toUpperCase() == 'AVAILABLE') return green;
    if (actualText.isEmpty) {
      // Planned for a week that has come, but nothing done
      final order = orderDate == null ? null : num.tryParse(cells[orderDate!].trim());
      final planValue = num.tryParse(planText);
      if (planValue == null || order == null) return null;
      return planValue <= currentWeek - order + 1 ? red : null;
    }
    final actualValue = num.tryParse(actualText);
    final planValue = num.tryParse(planText);
    if (actualValue == null || planValue == null) return null;
    final diff = actualValue - planValue;
    if (diff <= 1) return green;
    if (diff <= 5) return orange;
    return red;
  }
}

/// ISO 8601 week number of a date (week 1 holds the year's first Thursday).
int isoWeekOf(DateTime date) {
  final thursday = DateTime(date.year, date.month, date.day + (4 - date.weekday));
  return thursday.difference(DateTime(thursday.year, 1, 1)).inDays ~/ 7 + 1;
}

/// Orders per schedule status. One row is one order, counted once by its status (see PlanColours.statusOf).
class ScheduleCounts {
  ScheduleCounts({this.onSchedule = 0, this.atRisk = 0, this.delayed = 0});

  int onSchedule;
  int atRisk;
  int delayed;

  static ScheduleCounts ofProducts(PlanColours plan, List<Map<String, dynamic>> products) {
    final counts = ScheduleCounts();
    for (final product in products) {
      if (product['is_comment'] == true) continue; // note rows are not orders
      final stageDone = List<bool>.from(product['stage_done'] as List);
      final finalQc = plan.finalQcStage;
      if (finalQc != null && finalQc < stageDone.length && stageDone[finalQc]) {
        counts.onSchedule++; // FINAL QC is yellow: finished, whatever block 2 and 3 show
        continue;
      }
      final status = plan.statusOf(List<String>.from(product['cells'] as List));
      if (status == PlanColours.green) counts.onSchedule++;
      if (status == PlanColours.orange) counts.atRisk++;
      if (status == PlanColours.red) counts.delayed++;
    }
    return counts;
  }

  void add(ScheduleCounts other) {
    onSchedule += other.onSchedule;
    atRisk += other.atRisk;
    delayed += other.delayed;
  }
}

/// The three schedule counts, each with its status colour.
class ScheduleSummary extends StatelessWidget {
  const ScheduleSummary({super.key, required this.counts});

  final ScheduleCounts counts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _line('On schedule', counts.onSchedule, PlanColours.green),
        _line('At risk of delay', counts.atRisk, PlanColours.orange),
        _line('Delayed', counts.delayed, PlanColours.red),
      ],
    );
  }

  Widget _line(String label, int count, Color colour) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 16, height: 16, color: colour),
          const SizedBox(width: 8),
          Text('$label: $count orders', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Width for a dashboard pop-up: at most [max], never wider than the screen.
double dashboardDialogWidth(BuildContext context, double max) {
  final available = MediaQuery.sizeOf(context).width - 48;
  return available < max ? available : max;
}

/// Per-supplier counts. The supplier name column stays fixed; the count columns scroll sideways
/// (mouse wheel, trackpad, scrollbar, mouse drag and touch swipe).
class ScheduleTable extends StatefulWidget {
  const ScheduleTable({super.key, required this.rows});

  final List<SupplierSchedule> rows;

  @override
  State<ScheduleTable> createState() => _ScheduleTableState();
}

class _ScheduleTableState extends State<ScheduleTable> {
  static const double _nameWidth = 160;
  static const double _countWidth = 130;
  static const double _headerHeight = 48;
  static const double _rowHeight = 40;

  final ScrollController _sideways = ScrollController();

  @override
  void dispose() {
    _sideways.dispose();
    super.dispose();
  }

  Widget _countCell(String text, {bool header = false}) {
    return Container(
      width: _countWidth,
      height: header ? _headerHeight : _rowHeight,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: header ? kTimelineBordeaux.withValues(alpha: 0.1) : null,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Text(text, style: header ? const TextStyle(fontWeight: FontWeight.bold) : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const TimelineScrollBehavior(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed: supplier names
          Column(
            children: [
              Container(
                width: _nameWidth,
                height: _headerHeight,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: kTimelineBordeaux.withValues(alpha: 0.1),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
                ),
                child: const Text('Supplier', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              for (final row in widget.rows)
                Container(
                  width: _nameWidth,
                  height: _rowHeight,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
                  child: Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
          // Scrolls sideways: the three counts
          Expanded(
            child: Scrollbar(
              controller: _sideways,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _sideways,
                scrollDirection: Axis.horizontal,
                child: Column(
                  children: [
                    Row(children: [
                      _countCell('On schedule', header: true),
                      _countCell('At risk of delay', header: true),
                      _countCell('Delayed', header: true),
                    ]),
                    for (final row in widget.rows)
                      Row(children: [
                        _countCell('${row.counts!.onSchedule}'),
                        _countCell('${row.counts!.atRisk}'),
                        _countCell('${row.counts!.delayed}'),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableColumn {
  const _TableColumn({
    required this.index,
    required this.label,
    required this.width,
    this.isProgress = false,
    this.fixedBackground,
    this.weekStage = false,
  });

  final int index;
  final String label;
  final double width;
  final bool isProgress;
  final Color? fixedBackground;
  final bool weekStage;
}
