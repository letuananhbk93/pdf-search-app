import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/timeline_service.dart';
import '../widgets/timeline_widgets.dart';
import 'projects_screen.dart' show ProcessSearchDelegate;
import 'timeline_detail_screens.dart';

/// Screen 1: TIMELINE. Year buttons, Reload from Google Drive, and the manual upload fallback.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final TimelineService _service = TimelineService();
  late Future<Map<String, dynamic>> _future = _service.fetchYears();
  Map<String, dynamic>? _status;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  void _loadYears() => setState(() => _future = _service.fetchYears());

  Future<void> _refreshStatus() async {
    final Map<String, dynamic> status;
    try {
      status = await _service.fetchStatus();
    } on TimelineException {
      return; // The next poll tick tries again.
    }
    if (!mounted) return;

    final wasRunning = _status?['running'] == true;
    setState(() => _status = status);
    if (status['running'] == true) {
      _poller ??= Timer.periodic(const Duration(seconds: 3), (_) => _refreshStatus());
      return;
    }
    _poller?.cancel();
    _poller = null;
    if (wasRunning) {
      _loadYears();
      _showSyncErrors(status);
    }
  }

  Future<void> _reload() async {
    try {
      await _service.startReload();
    } on TimelineException catch (e) {
      _showMessage(e.message);
      return;
    }
    await _refreshStatus();
  }

  Future<void> _uploadFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
      allowMultiple: false,
    );
    final file = picked?.files.single;
    if (file == null) return;

    final Map<String, dynamic> preview;
    try {
      preview = await _service.previewUpload(file);
    } on TimelineException catch (e) {
      _showMessage(e.message);
      return;
    }
    if (!mounted) return;

    final save = await showDialog<bool>(
      context: context,
      builder: (_) => _UploadPreviewDialog(preview: preview),
    );
    if (save != true || !mounted) return;

    try {
      await _service.saveUpload(file, allowOlder: preview['older_than_stored'] == true);
    } on TimelineException catch (e) {
      _showMessage(e.message);
      return;
    }
    _showMessage('Saved ${preview['po_key']}');
    _loadYears();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSyncErrors(Map<String, dynamic> status) {
    final errors = List<Map<String, dynamic>>.from(status['errors'] as List);
    if (errors.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${errors.length} file(s) could not be updated'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final error in errors)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text('${error['file'] ?? 'Sync'}: ${error['error']}'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final running = _status?['running'] == true;
    return Scaffold(
      appBar: buildTimelineAppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            tooltip: 'Search',
            onPressed: () => showSearch(context: context, delegate: ProcessSearchDelegate()),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file, color: Colors.white),
            tooltip: 'Upload Excel (fallback)',
            onPressed: running ? null : _uploadFile,
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.sync),
            label: const Text('Reload'),
            onPressed: running ? null : _reload,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (running) _buildProgress(),
          Expanded(
            child: TimelineBody(
              path: const ['TIMELINE'],
              future: _future,
              onRetry: _loadYears,
              builder: _buildYears,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final total = (_status?['total'] as num?)?.toInt() ?? 0;
    final done = (_status?['done'] as num?)?.toInt() ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_status?['message'] ?? 'Syncing...'}'),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: total > 0 ? done / total : null, color: kTimelineBordeaux),
        ],
      ),
    );
  }

  Widget _buildYears(BuildContext context, Map<String, dynamic> data) {
    final years = List<int>.from(data['years'] as List);
    if (years.isEmpty) {
      return const Center(
        child: Text('No timeline data yet. Press Reload to load it from Google Drive.',
            style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final year in years)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kTimelineBordeaux,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(64),
                textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TimelinePoScreen(year: year, path: ['TIMELINE', '$year'])),
              ),
              child: Text('$year'),
            ),
          ),
      ],
    );
  }
}

/// Shows what a manual upload would store. Save is only offered after this preview.
class _UploadPreviewDialog extends StatelessWidget {
  const _UploadPreviewDialog({required this.preview});

  final Map<String, dynamic> preview;

  @override
  Widget build(BuildContext context) {
    final suppliers = List<Map<String, dynamic>>.from(preview['suppliers'] as List);
    final ignored = List<String>.from(preview['ignored_sheets'] as List);
    final stored = preview['stored'] as Map<String, dynamic>?;
    final older = preview['older_than_stored'] == true;
    final pct = (preview['overall_pct'] as num).toDouble();

    return AlertDialog(
      title: Text('PO${preview['po_no']} (${preview['year']}) preview'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('File: ${preview['file_name']}'),
              const SizedBox(height: 6),
              Text('Suppliers: ${preview['supplier_count']}    Products: ${preview['product_count']}'),
              const SizedBox(height: 6),
              Text('Overall: ${pct.round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: (pct / 100).clamp(0.0, 1.0),
                color: timelineProgressColor(pct),
                backgroundColor: Colors.grey.shade200,
              ),
              const SizedBox(height: 12),
              for (final supplier in suppliers)
                Text('${supplier['name']}: ${supplier['products']} products, '
                    '${supplier['stages']} stages (${(supplier['pct'] as num).round()}%)'),
              if (ignored.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Ignored sheets: ${ignored.join(', ')}', style: const TextStyle(color: Colors.black54)),
              ],
              if (stored != null) ...[
                const SizedBox(height: 8),
                Text('Currently stored: ${stored['file_name']}'),
              ],
              if (older) ...[
                const SizedBox(height: 8),
                Text(
                  'This file is older than the stored one (${stored?['file_date'] ?? 'unknown date'}). '
                  'Saving will overwrite newer data.',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(older ? 'Overwrite anyway' : 'Save'),
        ),
      ],
    );
  }
}
