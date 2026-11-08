import 'dart:typed_data';

import 'package:pdfx/pdfx.dart';

Future<Uint8List> renderPdfPage(
  PdfDocument document,
  int pageNumber,
  double width,
) async {
  final page = await document.getPage(pageNumber);
  try {
    final image = await page.render(
      width: width,
      height: width * page.height / page.width,
      format: PdfPageImageFormat.jpeg,
      quality: 90,
      backgroundColor: '#FFFFFF',
    );
    if (image == null) {
      throw StateError('Could not render page $pageNumber');
    }
    return image.bytes;
  } finally {
    await page.close();
  }
}
