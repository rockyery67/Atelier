import 'dart:io';
import 'dart:convert';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final directory = Directory('docs/device');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes);
    return true;
  },
  responseDataCallback: (data) async {
    final directory = Directory('docs/device');
    await directory.create(recursive: true);
    await File('${directory.path}/integration.json').writeAsString(
      const JsonEncoder.withIndent('  ')
          .convert({...?data}..remove('screenshots')),
    );
  },
);
