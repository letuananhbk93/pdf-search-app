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
          return GridView.builder(
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
          );
        },
      ),
    );
  }
}

/// Screen 4: the supplier's timeline table; completed stage cells are tinted yellow.
/// Tap a header to sort by it, double tap to hide it, right-click or hold a header for 2 seconds to unhide.
class TimelineTableScreen extends StatefulWidget {
  const TimelineTableScreen({super.key, required this.supplierId, required this.path});

  final int supplierId;
  final List<String> path;

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
      appBar: buildTimelineAppBar(),
      body: TimelineBody(
        path: widget.path,
        future: _future,
        onRetry: _retry,
        builder: (context, data) {
          final headers = List<String>.from(data['headers'] as List);
          final stageColumns = List<int>.from(data['stage_columns'] as List);
          final products = List<Map<String, dynamic>>.from(data['products'] as List);
          if (products.isEmpty) {
            return const Center(child: Text('No products', style: TextStyle(color: Colors.grey)));
          }

          // Column index -> position in stage_done (only stage columns have one)
          final stagePosition = {for (var i = 0; i < stageColumns.length; i++) stageColumns[i]: i};

          // Progress is appended after the backend columns; swap it with IMAGE so it sits where IMAGE was
          final progressColumn = headers.length;
          final imageColumn = headers.indexWhere((header) => header.toUpperCase() == 'IMAGE');
          final columnOrder = List<int>.generate(headers.length + 1, (i) => i);
          if (imageColumn >= 0) {
            columnOrder[imageColumn] = progressColumn;
            columnOrder[progressColumn] = imageColumn;
          }

          final columns = <_TableColumn>[];
          for (final column in columnOrder) {
            if (_hiddenColumns.containsKey(column)) continue;
            if (column == progressColumn) {
              columns.add(_TableColumn(index: column, label: 'Progress', width: _progressWidth, isProgress: true));
            } else {
              final label = headers[column];
              final width = _narrowHeaders.contains(label.toUpperCase()) ? _narrowColumnWidth : _columnWidth;
              columns.add(_TableColumn(index: column, label: label, width: width));
            }
          }

          final sortColumn = _sortColumn;
          final productOrder = sortColumn == null
              ? [for (var i = 0; i < products.length; i++) if (!_isNote(products[i])) i]
              : _sortOrder(products, sortColumn, progressColumn);
          final order = _withNotes(productOrder, products);
          final tableWidth = columns.fold<double>(0, (total, column) => total + column.width);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Yellow cells: stage completed. Blue rows are notes (no QTY), not products. '
                  'Tap a header to sort (tap again to undo), double tap to hide, '
                  'right-click or hold a header 2 seconds to unhide. Tap a row to show its full text.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
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
                                  _productRow(index, products[index], columns, stagePosition),
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

  Widget _productRow(int index, Map<String, dynamic> product, List<_TableColumn> columns, Map<int, int> stagePosition) {
    final cells = List<String>.from(product['cells'] as List);
    final stageDone = List<bool>.from(product['stage_done'] as List);
    final expanded = _expandedRows.contains(index);
    final row = Row(
      crossAxisAlignment: expanded ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
      children: [
        for (final column in columns)
          column.isProgress
              ? _progressCell((product['pct'] as num).toDouble(), column.width)
              : _textCell(
                  cells[column.index],
                  width: column.width,
                  done: stagePosition.containsKey(column.index) && stageDone[stagePosition[column.index]!],
                  expanded: expanded,
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

  double _paddingFor(double width) => width == _narrowColumnWidth ? 4 : 12;

  Widget _textCell(String text, {required double width, required bool done, required bool expanded}) {
    return Container(
      width: width,
      height: expanded ? null : _rowHeight,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: _paddingFor(width), vertical: expanded ? 8 : 0),
      color: done ? const Color(0xFFFFFF00) : null,
      child: Text(text, maxLines: expanded ? null : 2, overflow: expanded ? null : TextOverflow.ellipsis),
    );
  }

  Widget _progressCell(double pct, double width) {
    final color = timelineProgressColor(pct);
    return SizedBox(
      width: width,
      height: _rowHeight,
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

class _TableColumn {
  const _TableColumn({required this.index, required this.label, required this.width, this.isProgress = false});

  final int index;
  final String label;
  final double width;
  final bool isProgress;
}
