import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('release source keeps UID guards and notification declarations', () {
    final firestore = source('firestore.rules');
    final storage = source('storage.rules');
    final manifest = source('android/app/src/main/AndroidManifest.xml');

    expect(firestore, contains('request.auth.uid'));
    expect(storage, contains('request.auth.uid == userId'));
    expect(storage, isNot(contains('allow read, write: if signedIn();')));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
  });

  test('Web manifest has install metadata and source has no reset secrets', () {
    final manifest = source('web/manifest.json');
    final files = <String>[
      source('lib/services/auth_service.dart'),
      source('lib/controllers/auth_controller.dart'),
      source('test/services/auth_controller_test.dart'),
    ].join('\n');

    expect(manifest, contains('"display": "standalone"'));
    expect(manifest, contains('"start_url"'));
    expect(files, isNot(contains('reset-token')));
    expect(files, isNot(contains('reset_link')));
  });
}