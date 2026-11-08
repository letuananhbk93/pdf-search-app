import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../models/lacquer_document.dart';
import '../services/lacquer_documents_service.dart';

const _bordeaux = Color(0xFFC00000);
const _paper = Color(0xFF3B3B3B);

class LacquerDocumentReaderScreen extends StatefulWidget {
  const LacquerDocumentReaderScreen({super.key, required this.document});

  final LacquerDocument document;

  @override
  State<LacquerDocumentReaderScreen> createState() =>
      _LacquerDocumentReaderScreenState();
}

class _LacquerDocumentReaderScreenState
    extends State<LacquerDocumentReaderScreen> {
  late final Future<PdfDocument> _document;
  late final PdfController _controller;

  @override
  void initState() {
    super.initState();
    _document = LacquerDocumentsService()
        .downloadPdf(widget.document.id)
        .then((bytes) => PdfDocument.openData(bytes));
    _controller = PdfController(document: _document);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        title: Text(
          widget.document.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: _bordeaux,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<PdfDocument>(
        future: _document,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ReaderMessage(
              message:
                  'Could not open document.\n${errorMessage(snapshot.error!)}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          final count = snapshot.data!.pagesCount;
          return Stack(
            children: [
              PdfView(controller: _controller),
              ValueListenableBuilder<int>(
                valueListenable: _controller.pageListenable,
                builder: (context, page, _) => Stack(
                  children: [
                    Positioned(
                      left: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _FloatingNavButton(
                          icon: Icons.chevron_left,
                          label: 'Back',
                          onPressed: page > 1
                              ? () => _controller.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                )
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: _FloatingNavButton(
                          icon: Icons.chevron_right,
                          label: 'Next',
                          iconAfterLabel: true,
                          onPressed: page < count
                              ? () => _controller.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                )
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Page $page of $count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FloatingNavButton extends StatefulWidget {
  const _FloatingNavButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconAfterLabel = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool iconAfterLabel;

  @override
  State<_FloatingNavButton> createState() => _FloatingNavButtonState();
}

class _FloatingNavButtonState extends State<_FloatingNavButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final highlighted = enabled && _hovering;
    final iconLabel = [
      Icon(widget.icon, color: Colors.white, size: 22),
      Text(
        widget.label,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    ];

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: highlighted
                ? Colors.black.withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: widget.onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.iconAfterLabel
                      ? iconLabel.reversed.toList()
                      : iconLabel,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReaderMessage extends StatelessWidget {
  const _ReaderMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
