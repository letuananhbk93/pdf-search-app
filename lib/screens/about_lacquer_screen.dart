import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

import '../models/lacquer_document.dart';
import '../services/about_presentation_cache.dart';
import '../services/lacquer_documents_service.dart';
import '../services/pdf_page_renderer.dart';

const _bordeaux = Color(0xFFC00000);
const _stage = Color(0xFF141414);
const _defaultTitle = 'ABOUT LACQUER';
const _slideRenderWidth = 1600.0;
const _minZoom = 1.0;
const _maxZoom = 3.0;
const _zoomStep = 0.25;

class AboutLacquerScreen extends StatefulWidget {
  const AboutLacquerScreen({super.key});

  @override
  State<AboutLacquerScreen> createState() => _AboutLacquerScreenState();
}

class _AboutLacquerScreenState extends State<AboutLacquerScreen> {
  final LacquerDocumentsService _service = LacquerDocumentsService();
  final AboutPresentationCache _cache = AboutPresentationCache();
  final TransformationController _zoomController = TransformationController();
  final GlobalKey _viewerKey = GlobalKey();
  late Future<PdfDocument?> _document;
  String _title = _defaultTitle;
  final Map<int, Future<Uint8List>> _slides = {};
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _document = _loadSavedPresentation();
  }

  @override
  void dispose() {
    _document.then((document) => document?.close(), onError: (_) {});
    _zoomController.dispose();
    super.dispose();
  }

  // Shows the device copy at once, then checks the server for a newer one.
  // Null means no presentation has been saved on the server yet.
  Future<PdfDocument?> _loadSavedPresentation() async {
    final cached = await _cache.read();
    if (cached != null) {
      _applyTitle(cached.title);
      _refreshFromServer(cached);
      return PdfDocument.openData(cached.bytes);
    }
    final presentation = await _service.getAboutLacquerPdf();
    if (presentation == null) return null;
    await _cache.write(presentation);
    _applyTitle(presentation.title);
    return PdfDocument.openData(presentation.bytes);
  }

  // Replaces the open presentation only when the server has a different one.
  Future<void> _refreshFromServer(AboutPresentation cached) async {
    try {
      final latest = await _service.getAboutLacquerPdf();
      if (latest == null) {
        await _cache.clear();
        return;
      }
      if (latest.title == cached.title &&
          listEquals(latest.bytes, cached.bytes)) {
        return;
      }
      await _cache.write(latest);
      if (!mounted) return;
      _showPresentation(PdfDocument.openData(latest.bytes), latest.title);
    } catch (_) {
      // Offline or server error: keep showing the saved copy.
    }
  }

  void _applyTitle(String title) {
    if (!mounted) return;
    setState(() => _title = title.isEmpty ? _defaultTitle : title);
  }

  double get _zoom => _zoomController.value.getMaxScaleOnAxis();

  void _zoomBy(double step) {
    final current = _zoom;
    final target = (current + step).clamp(_minZoom, _maxZoom).toDouble();
    if (target == current) return;
    if (target <= _minZoom) {
      _zoomController.value = Matrix4.identity();
      return;
    }
    final box = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = box.size.center(Offset.zero);
    final scaleAboutCenter = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(target / current)
      ..translate(-center.dx, -center.dy);
    _zoomController.value = scaleAboutCenter * _zoomController.value;
  }

  Future<Uint8List> _slideBytes(PdfDocument document, int index) {
    return _slides.putIfAbsent(
      index,
      () => renderPdfPage(document, index + 1, _slideRenderWidth),
    );
  }

  void _goTo(int index) {
    setState(() => _index = index);
  }

  void _showPresentation(Future<PdfDocument?> document, String title) {
    final previous = _document;
    _zoomController.value = Matrix4.identity();
    setState(() {
      _document = document;
      _title = title.isEmpty ? _defaultTitle : title;
      _index = 0;
      _slides.clear();
    });
    previous.then((document) => document?.close(), onError: (_) {});
  }

  Future<void> _selectPresentation() async {
    try {
      final documents = (await _service.listDocuments())
          .where((d) => d.isReady)
          .toList();
      if (!mounted) return;
      if (documents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No ready documents. Upload one in Other Documents first.',
            ),
          ),
        );
        return;
      }

      final choice = await showDialog<LacquerDocument>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('Select presentation'),
          children: [
            for (final document in documents)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, document),
                child: Text(document.title),
              ),
          ],
        ),
      );
      if (choice == null || !mounted) return;

      final bytes = await _service.downloadPdf(choice.id);
      final presentation = AboutPresentation(bytes: bytes, title: choice.title);
      await _service.saveAboutLacquerPdf(presentation);
      await _cache.write(presentation);
      if (!mounted) return;
      _showPresentation(PdfDocument.openData(bytes), choice.title);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not select presentation: ${errorMessage(e)}'),
          backgroundColor: _bordeaux,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _stage,
      appBar: AppBar(
        title: Text(
          _title,
          style: const TextStyle(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: _bordeaux,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Colors.white),
            tooltip: 'Zoom out',
            onPressed: () => _zoomBy(-_zoomStep),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Colors.white),
            tooltip: 'Zoom in',
            onPressed: () => _zoomBy(_zoomStep),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.white),
            tooltip: 'Menu',
            onSelected: (choice) {
              switch (choice) {
                case 'select_presentation':
                  _selectPresentation();
                case 'other_documents':
                  Navigator.pushNamed(context, '/other-documents');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'select_presentation',
                child: Row(
                  children: [
                    Icon(Icons.slideshow_outlined, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Select presentation'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'other_documents',
                child: Row(
                  children: [
                    Icon(Icons.folder_copy_outlined, color: Colors.black54),
                    SizedBox(width: 12),
                    Text('Other Documents'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<PdfDocument?>(
        future: _document,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not open slides.\n${errorMessage(snapshot.error!)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }
          final document = snapshot.data;
          if (document == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No presentation selected.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _selectPresentation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _bordeaux,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Select presentation'),
                  ),
                ],
              ),
            );
          }
          final count = document.pagesCount;
          final index = _index.clamp(0, count - 1);

          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowRight): () {
                if (index < count - 1) _goTo(index + 1);
              },
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
                if (index > 0) _goTo(index - 1);
              },
            },
            child: Focus(
              autofocus: true,
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: FutureBuilder<Uint8List>(
                        future: _slideBytes(document, index),
                        builder: (context, slide) {
                          if (slide.hasError) {
                            return const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 56,
                                color: Colors.white54,
                              ),
                            );
                          }
                          if (!slide.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            );
                          }
                          return InteractiveViewer(
                            key: _viewerKey,
                            transformationController: _zoomController,
                            minScale: _minZoom,
                            maxScale: _maxZoom,
                            child: Image.memory(
                              slide.data!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  _SlideControls(
                    index: index,
                    count: count,
                    onBack: index > 0 ? () => _goTo(index - 1) : null,
                    onNext: index < count - 1 ? () => _goTo(index + 1) : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SlideControls extends StatelessWidget {
  const _SlideControls({
    required this.index,
    required this.count,
    required this.onBack,
    required this.onNext,
  });

  final int index;
  final int count;
  final VoidCallback? onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: _bordeaux,
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.white12,
      disabledForegroundColor: Colors.white30,
      minimumSize: const Size(120, 48),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      color: const Color(0xFF1F1F1F),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: onBack,
            style: buttonStyle,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Slide ${index + 1} of $count',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (index + 1) / count,
                    minHeight: 4,
                    color: _bordeaux,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton.icon(
            onPressed: onNext,
            style: buttonStyle,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
