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
                subtitle: '${po['product_count']} products',
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

/// Screen 4: the supplier's timeline table with a Progress column; completed stage cells are tinted green.
class TimelineTableScreen extends StatefulWidget {
  const TimelineTableScreen({super.key, required this.supplierId, required this.path});

  final int supplierId;
  final List<String> path;

  @override
  State<TimelineTableScreen> createState() => _TimelineTableScreenState();
}

class _TimelineTableScreenState extends State<TimelineTableScreen> {
  static const double _columnWidth = 140;
  static const double _rowHeight = 44;

  final TimelineService _service = TimelineService();
  late Future<Map<String, dynamic>> _future = _service.fetchSupplier(widget.supplierId);

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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('Yellow cells: stage completed', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 0,
                      horizontalMargin: 0,
                      dataRowMinHeight: _rowHeight,
                      dataRowMaxHeight: _rowHeight,
                      headingRowColor: WidgetStateProperty.all(kTimelineBordeaux.withValues(alpha: 0.1)),
                      columns: [
                        for (final header in headers)
                          DataColumn(label: _headerLabel(header, _columnWidth)),
                        DataColumn(label: _headerLabel('Progress', 100)),
                      ],
                      rows: products.map((product) {
                        final cells = List<String>.from(product['cells'] as List);
                        final stageDone = List<bool>.from(product['stage_done'] as List);
                        return DataRow(
                          cells: [
                            for (var column = 0; column < headers.length; column++)
                              DataCell(_textCell(
                                cells[column],
                                done: stagePosition.containsKey(column) && stageDone[stagePosition[column]!],
                              )),
                            DataCell(_progressCell((product['pct'] as num).toDouble())),
                          ],
                        );
                      }).toList(),
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

  Widget _headerLabel(String text, double width) {
    return SizedBox(
      width: width - 12,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _textCell(String text, {required bool done}) {
    return Container(
      width: _columnWidth,
      height: _rowHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: done ? const Color(0xFFFFFF00) : null,
      child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _progressCell(double pct) {
    final color = timelineProgressColor(pct);
    return SizedBox(
      width: 100,
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
