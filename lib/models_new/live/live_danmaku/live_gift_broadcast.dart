import 'dart:convert';

import 'package:protobuf/protobuf.dart';
import 'package:PiliPlus/models_new/live/live_danmaku/live_wire_decoder.dart';

/// Minimal public SendGiftBroadcast schema from the official room client.
/// Identity recovery fields are deliberately not read.
abstract final class LiveGiftBroadcast {
  static Map<String, dynamic>? decode(String encoded) {
    if (encoded.length > 2 * 1024 * 1024) return null;
    try {
      final reader = CodedBufferReader(base64Decode(encoded));
      final gifts = <Map<String, dynamic>>[];
      final result = <String, dynamic>{'gift_list': gifts};
      for (var tag = reader.readTag(); tag != 0; tag = reader.readTag()) {
        switch (tag) {
          case 8:
            result['uid'] = reader.readInt64().toInt();
          case 18:
            result['uname'] = reader.readString();
          case 82:
            if (gifts.length >= 1000) return null;
            gifts.add(_gift(reader.readBytes()));
          case 88:
            result['switch'] = reader.readBool();
          case 122:
            result['sender_uinfo'] = _user(reader.readBytes());
          default:
            reader.skipField(tag);
        }
      }
      return result;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _gift(List<int> bytes) {
    final reader = CodedBufferReader(bytes);
    final result = <String, dynamic>{};
    for (var tag = reader.readTag(); tag != 0; tag = reader.readTag()) {
      switch (tag) {
        case 8:
          result['gift_id'] = reader.readInt64().toInt();
        case 18:
          result['gift_name'] = reader.readString();
        case 24:
          result['num'] = reader.readInt64().toInt();
        case 74:
          result['tid'] = reader.readString();
        case 146:
          result['action'] = reader.readString();
        case 282:
          result['gift_info'] = LiveWireDecoder.fields(
            reader.readBytes(),
            const {1: ('img_basic', 'string'), 2: ('webp', 'string')},
          );
        default:
          reader.skipField(tag);
      }
    }
    return result;
  }

  static Map<String, dynamic> _user(List<int> bytes) {
    return LiveWireDecoder.fields(bytes, LiveWireDecoder.publicUser);
  }
}
