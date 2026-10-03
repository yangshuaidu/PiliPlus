import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/retry_interceptor.dart';
import 'package:PiliPlus/services/live_gift_service.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:dio/dio.dart';
import 'package:hive_ce/hive.dart';

LiveGiftService createLiveGiftService({
  required int roomId,
  required int anchorUid,
  int? areaId,
  int? parentAreaId,
}) => LiveGiftService(
  roomId: roomId,
  anchorUid: anchorUid,
  areaId: areaId,
  parentAreaId: parentAreaId,
  transport: _GiftTransport(roomId),
  journal: _GiftJournal(),
  currentAccount: () {
    final account = Accounts.main;
    return LiveGiftAccount(
      account.isLogin ? account.mid : 0,
      account,
      account.isLogin ? account.csrf : '',
    );
  },
);

class _GiftTransport implements LiveGiftTransport {
  final int roomId;
  Dio? _client;
  _GiftTransport(this.roomId);
  Dio get client => _client ??= Request.dio.clone()
    ..interceptors.removeWhere(
      (item) => item is RetryInterceptor || item is LogInterceptor,
    );

  Options _options(LiveGiftAccount account) => Options(
    extra: {'account': account.identity},
    contentType: Headers.formUrlEncodedContentType,
    followRedirects: false,
    maxRedirects: 0,
    sendTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'referer': 'https://live.bilibili.com/$roomId'},
  );
  static const origin = 'https://api.live.bilibili.com';
  Map<String, dynamic> _response(Object? data) {
    if (data is Map<String, dynamic>) return data;
    throw const LiveGiftException('服务器响应格式异常');
  }

  @override
  Future<Map<String, dynamic>> get(
    String path,
    Map<String, dynamic> query,
    LiveGiftAccount account,
  ) async => _response(
    (await client.get<dynamic>(
      origin + path,
      queryParameters: query,
      options: _options(account),
    )).data,
  );
  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
    LiveGiftAccount account,
  ) async => _response(
    (await client.post<dynamic>(
      origin + path,
      data: body,
      options: _options(account),
    )).data,
  );
  // The clone shares Request.dio's adapter; it must not close that adapter.
}

class _GiftJournal implements LiveGiftJournal {
  static Future<Box<dynamic>>? _opening;
  Future<Box<dynamic>> get _box async {
    try {
      return await (_opening ??= Hive.openBox<dynamic>('liveGiftJournal'));
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> read(String key) async {
    final value = (await _box).get(key);
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    final box = await _box;
    await box.put(key, value);
    await box.flush();
  }
}
