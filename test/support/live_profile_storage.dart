import 'dart:io';

import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// Profile widgets read the current account, whose anonymous identity uses the
/// local cache. Keep this storage isolated from any real account or app data.
void setUpLiveProfileStorage() {
  late Directory directory;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('live-profile-test-');
    Hive.init(directory.path);
    GStorage.localCache = await Hive.openBox<dynamic>('localCache');
    GStorage.setting = await Hive.openBox<dynamic>('setting');
  });
  tearDownAll(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });
}
