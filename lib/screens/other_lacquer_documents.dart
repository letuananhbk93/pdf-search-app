import 'package:flutter/material.dart';

import '../models/lacquer_document.dart';
import '../services/lacquer_documents_service.dart';
import 'lacquer_document_reader.dart';

const _bordeaux = Color(0xFFC00000);

class OtherLacquerDocumentsScreen extends StatefulWidget {
  const OtherLacquerDocumentsScreen({super.key});

  @override
  State<OtherLacquerDocumentsScreen> createState() =>
      _OtherLacquerDocumentsScreenState();
}

class _OtherLacquerDocumentsScreenState
    extends State<OtherLacquerDocumentsScreen> {
  final LacquerDocumentsService _service = LacquerDocumentsService();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<LacquerDocument>> _documents;
  String _query = '';
  double? _uploadProgress;

  bool get _uploading => _uploadProgress != null;

  @override
  void initState() {
    super.initState();
    _documents = _service.listDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _documents = _service.listDocuments());
  }

  // Pull-to-refresh waits for the new list, so the spinner goes away when it's loaded.
  Future<void> _refresh() async {
    _reload();
    try {
      await _documents;
    } catch (_) {
      // The error is shown in the list area.
    }
  }

  Future<void> _upload() async {
    try {
      final file = await _service.pickDocument();
      if (file == null) return;

      setState(() => _uploadProgress = 0);
      await _service.uploadDocument(
        file,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );
      if (!mounted) return;
      _reload();
      _showMessage('Uploaded ${file.name}', Colors.green);
    } catch (e) {
      if (mounted) _showMessage('Upload failed: ${errorMessage(e)}', _bordeaux);
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
    }
  }

  Future<void> _delete() async {
    try {
      final documents = await _service.listDocuments();
      if (!mounted) return;
      if (documents.isEmpty) {
        _showMessage('No documents to delete', Colors.orange);
        return;
      }

      final selectedIds = await showDialog<Set<String>>(
        context: context,
        builder: (dialogContext) {
          final selected = <String>{};
          return StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('Select documents to delete'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final document in documents)
                      CheckboxListTile(
                        value: selected.contains(document.id),
                        title: Text(document.title),
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: _bordeaux,
                        onChanged: (checked) => setDialogState(() {
                          if (checked == true) {
                            selected.add(document.id);
                          } else {
                            selected.remove(document.id);
                          }
                        }),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(dialogContext, selected),
                  child: Text(
                    'Delete (${selected.length})',
                    style: const TextStyle(color: _bordeaux),
                  ),
                ),
              ],
            ),
          );
        },
      );
      if (selectedIds == null || !mounted) return;

      final selectedDocuments = documents
          .where((document) => selectedIds.contains(document.id))
          .toList();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(
            'Delete ${selectedDocuments.length} document(s)? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete', style: TextStyle(color: _bordeaux)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final result = await _service.deleteDocuments(
        selectedDocuments.map((document) => document.id).toList(),
      );
      if (!mounted) return;
      _reload();
      if (result.failed.isEmpty) {
        _showMessage(
          'Deleted ${result.deleted.length} document(s)',
          Colors.green,
        );
      } else {
        final failedTitles = selectedDocuments
            .where((document) => result.failed.containsKey(document.id))
            .map(
              (document) => '${document.title}: ${result.failed[document.id]}',
            );
        _showMessage(
          'Failed to delete ${result.failed.length}: ${failedTitles.join('; ')}',
          _bordeaux,
        );
      }
    } catch (e) {
      if (mounted) _showMessage('Delete failed: ${errorMessage(e)}', _bordeaux);
    }
  }

  void _showMessage(String text, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  void _open(LacquerDocument document) {
    if (document.isFailed) {
      _showMessage('"${document.title}" could not be converted', _bordeaux);
      return;
    }
    if (!document.isReady) {
      _showMessage(
        '"${document.title}" is still being processed',
        Colors.orange,
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LacquerDocumentReaderScreen(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3F3),
      appBar: AppBar(
        title: const Text(
          'OTHER DOCUMENTS',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: _bordeaux,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
            tooltip: 'Menu',
            onSelected: (choice) {
              switch (choice) {
                case 'refresh':
                  _reload();
                case 'delete':
                  _delete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Refresh'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Delete'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<LacquerDocument>>(
        future: _documents,
        builder: (context, snapshot) {
          final header = _buildHeader();
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Column(
              children: [
                header,
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          if (snapshot.hasError) {
            return Column(
              children: [
                header,
                Expanded(
                  child: _MessageView(
                    icon: Icons.cloud_off_outlined,
                    message:
                        'Could not load documents.\n${errorMessage(snapshot.error!)}',
                    actionLabel: 'Retry',
                    onAction: _reload,
                  ),
                ),
              ],
            );
          }
          final allDocuments = snapshot.data ?? [];
          if (allDocuments.isEmpty) {
            return Column(
              children: [
                header,
                const Expanded(
                  child: _MessageView(
                    icon: Icons.folder_open_outlined,
                    message: 'No documents yet.\nTap "Upload file" to add one.',
                  ),
                ),
              ],
            );
          }
          final documents = allDocuments
              .where(
                (document) => document.title.toLowerCase().contains(_query),
              )
              .toList();
          if (documents.isEmpty) {
            return Column(
              children: [
                header,
                Expanded(
                  child: _MessageView(
                    icon: Icons.search_off,
                    message:
                        'No documents match "${_searchController.text.trim()}".',
                  ),
                ),
              ],
            );
          }
          return Column(
            children: [
              header,
              Expanded(
                child: RefreshIndicator(
                  color: _bordeaux,
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: documents.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) => _DocumentCard(
                      document: documents[index],
                      onTap: () => _open(documents[index]),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lacquer reference documents',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3A1A1A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Select a document to read.',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _uploading ? null : _upload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _bordeaux,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                icon: _uploading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                          value: _uploadProgress,
                        ),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(
                  _uploading
                      ? 'Uploading ${(_uploadProgress! * 100).round()}%'
                      : 'Upload file',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search documents',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document, required this.onTap});

  final LacquerDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(document.kind);
    final (statusText, statusColor) = switch (document.status) {
      'ready' => (style.label, Colors.grey.shade600),
      'failed' => ('Conversion failed', _bordeaux),
      _ => ('Processing...', Colors.orange.shade800),
    };

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(style.icon, color: style.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 13, color: statusColor),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }

  static ({IconData icon, Color color, String label}) _styleFor(
    LacquerDocumentKind kind,
  ) {
    return switch (kind) {
      LacquerDocumentKind.word => (
        icon: Icons.article_outlined,
        color: const Color(0xFF2B579A),
        label: 'Word document',
      ),
      LacquerDocumentKind.excel => (
        icon: Icons.table_chart_outlined,
        color: const Color(0xFF217346),
        label: 'Excel workbook',
      ),
      LacquerDocumentKind.presentation => (
        icon: Icons.slideshow_outlined,
        color: const Color(0xFFD24726),
        label: 'PowerPoint presentation',
      ),
      LacquerDocumentKind.pdf => (
        icon: Icons.picture_as_pdf_outlined,
        color: _bordeaux,
        label: 'PDF document',
      ),
      LacquerDocumentKind.other => (
        icon: Icons.insert_drive_file_outlined,
        color: Colors.blueGrey,
        label: 'Document',
      ),
    };
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
