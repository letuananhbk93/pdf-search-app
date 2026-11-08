// Keeps the last About Lacquer presentation on the device so it opens instantly.
// Web has no file storage, so the web build always loads from the server.
export 'about_presentation_cache_stub.dart'
    if (dart.library.io) 'about_presentation_cache_io.dart';
