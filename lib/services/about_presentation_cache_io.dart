import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'lacquer_documents_service.dart';

class AboutPresentationCache {
  Future<File> _file(String name) async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$name');
  }

  Future<AboutPresentation?> read() async {
    final pdf = await _file('about_lacquer.pdf');
    final title = await _file('about_lacquer.title.txt');
    if (!await pdf.exists() || !await title.exists()) return null;
    return AboutPresentation(
      bytes: await pdf.readAsBytes(),
      title: await title.readAsString(),
    );
  }

  Future<void> write(AboutPresentation presentation) async {
    await (await _file('about_lacquer.pdf')).writeAsBytes(presentation.bytes);
    await (await _file(
      'about_lacquer.title.txt',
    )).writeAsString(presentation.title);
  }

  Future<void> clear() async {
    for (final name in ['about_lacquer.pdf', 'about_lacquer.title.txt']) {
      final file = await _file(name);
      if (await file.exists()) await file.delete();
    }
  }
}
