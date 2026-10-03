import 'dart:async';

import 'package:PiliPlus/models_new/live/gift/live_gift.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_message_parser.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_user_badges.dart';
import 'package:get/get.dart';

class LiveGiftEffect {
  LiveGiftEffect(this.message, this.url);
  final LiveGiftMessage message;
  final String url;
}

/// A bounded visual queue. Dropping an effect never drops its chat receipt.
class LiveGiftEffects {
  LiveGiftEffects({
    required this.loadCatalog,
    this.duration = const Duration(seconds: 3),
  });
  final Future<Map<String, dynamic>> Function() loadCatalog;
  final Duration duration;
  final current = Rxn<LiveGiftEffect>();
  final enabled = true.obs;
  final _queue = <LiveGiftMessage>[];
  Map<int, String>? _assets;
  Future<void>? _loading;
  Timer? _timer;
  bool _disposed = false, _advancing = false;
  int _generation = 0;

  void add(LiveGiftMessage gift) {
    if (_disposed || !enabled.value) return;
    if (_queue.length >= 10) _queue.removeAt(0);
    _queue.add(gift);
    _next();
  }

  void setEnabled(bool value) {
    enabled.value = value;
    if (!value) clear();
  }

  void clear() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _queue.clear();
    current.value = null;
  }

  Future<void> _loadAssets() async {
    try {
      final data = await loadCatalog();
      if (_disposed) return;
      final config = liveMap(data['gift_config']);
      _assets = {
        for (final gift in liveMaps(liveMap(config['base_config'])['list']))
          ?liveInt(gift['id']): liveAssetUrl(gift['gif'] ?? gift['webp']),
      };
    } catch (_) {
      _assets = {};
    }
  }

  Future<void> _next() async {
    if (_disposed ||
        _advancing ||
        current.value != null ||
        _queue.isEmpty ||
        !enabled.value) {
      return;
    }
    _advancing = true;
    final generation = _generation;
    final gift = _queue.removeAt(0);
    try {
      if (gift.animationUrl.isEmpty && _assets == null) {
        await (_loading ??= _loadAssets());
      }
      if (_disposed || generation != _generation || !enabled.value) return;
      current.value = LiveGiftEffect(
        gift,
        gift.animationUrl.isNotEmpty
            ? gift.animationUrl
            : _assets?[gift.giftId] ?? gift.imageUrl,
      );
      _timer = Timer(duration, () {
        current.value = null;
        _next();
      });
    } finally {
      _advancing = false;
      if (!_disposed &&
          current.value == null &&
          _queue.isNotEmpty &&
          enabled.value) {
        _next();
      }
    }
  }

  void dispose() {
    _disposed = true;
    clear();
  }
}
