export 'qr_saver_stub.dart'
    if (dart.library.js_interop) 'qr_saver_web.dart'
    if (dart.library.io) 'qr_saver_io.dart';
