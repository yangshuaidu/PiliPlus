import 'dart:convert';

import 'package:protobuf/protobuf.dart';

typedef LiveWireSchema = Map<int, (String, Object)>;

/// Selected public fields from the official room client's protobuf schemas.
/// Private origin/risk-control identity fields are intentionally omitted.
abstract final class LiveWireDecoder {
  static Map<String, dynamic>? decode(String encoded, LiveWireSchema schema) {
    if (encoded.length > 2 * 1024 * 1024) return null;
    try {
      return fields(base64Decode(encoded), schema);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> fields(List<int> bytes, LiveWireSchema schema) {
    final reader = CodedBufferReader(bytes);
    final result = <String, dynamic>{};
    for (var tag = reader.readTag(); tag != 0; tag = reader.readTag()) {
      final field = schema[tag >> 3];
      if (field == null) {
        reader.skipField(tag);
        continue;
      }
      final (key, type) = field;
      final wire = tag & 7;
      if (type == 'emote_map') {
        if (wire != 2) throw const FormatException('Invalid emoticon map');
        final entry = fields(reader.readBytes(), const {
          1: ('key', 'string'),
          2: ('value', _emoticon),
        });
        if (entry['key'] is String && entry['value'] is Map)
          (result.putIfAbsent(key, () => <String, dynamic>{})
                  as Map)[entry['key']] =
              entry['value'];
        continue;
      }
      if ((type == 'int' || type == 'bool') && wire != 0 ||
          (type is LiveWireSchema || type == 'string' || type == 'bytes') &&
              wire != 2) {
        throw const FormatException('Invalid protobuf field type');
      }
      result[key] = switch (type) {
        'string' => reader.readString(),
        'int' => reader.readInt64().toInt(),
        'bool' => reader.readBool(),
        'bytes' => reader.readBytes().isNotEmpty,
        final LiveWireSchema nested => fields(reader.readBytes(), nested),
        _ => throw const FormatException('Unsupported protobuf type'),
      };
    }
    return result;
  }

  static const _level = <int, (String, Object)>{1: ('level', 'int')};
  static const _publicBase = <int, (String, Object)>{
    1: ('name', 'string'),
    2: ('face', 'string'),
    4: ('is_mystery', 'bool'),
    8: ('name_color_str', 'string'),
  };
  static const publicUser = <int, (String, Object)>{
    1: ('uid', 'int'),
    2: ('base', _publicBase),
    3: (
      'medal',
      <int, (String, Object)>{
        1: ('name', 'string'),
        2: ('level', 'int'),
        9: ('is_light', 'int'),
        10: ('ruid', 'int'),
        11: ('guard_level', 'int'),
        15: ('v2_medal_color_start', 'string'),
        18: ('v2_medal_color_text', 'string'),
      },
    ),
    4: ('wealth', _level),
    5: ('title', <int, (String, Object)>{2: ('title_css_id', 'string')}),
    6: ('guard', _level),
    9: ('anonymous', 'bytes'),
  };
  static const _dmUser = <int, (String, Object)>{
    1: ('uid', 'int'),
    2: ('name', 'string'),
    3: ('name_color', 'string'),
    10: ('attr', 'int'),
    11: (
      'medal',
      <int, (String, Object)>{
        1: ('level', 'int'),
        2: ('name', 'string'),
        9: ('privilege', 'int'),
        10: ('light', 'int'),
      },
    ),
    12: (
      'level',
      <int, (String, Object)>{1: ('level', 'int'), 4: ('online_rank', 'int')},
    ),
    13: ('title', <int, (String, Object)>{1: ('title', 'string')}),
    15: ('wealth', _level),
  };
  static const _emoticon = <int, (String, Object)>{
    1: ('emoticon_unique', 'string'),
    2: ('url', 'string'),
    3: ('is_dynamic', 'bool'),
    4: ('in_player_area', 'int'),
    5: ('bulge_display', 'int'),
    6: ('height', 'int'),
    7: ('width', 'int'),
  };
  static const danmakuSchema = <int, (String, Object)>{
    1: ('id_str', 'string'),
    2: ('mode', 'int'),
    4: ('color', 'int'),
    6: ('content', 'string'),
    7: ('ctime', 'int'),
    11: ('biz_scene', 'int'),
    13: ('dm_type', 'int'),
    14: ('emoticons', 'emote_map'),
    19: (
      'check',
      <int, (String, Object)>{1: ('token', 'string'), 2: ('ts', 'int')},
    ),
    20: ('user', _dmUser),
    23: (
      'reply',
      <int, (String, Object)>{
        1: ('show_reply', 'bool'),
        2: ('reply_mid', 'int'),
        3: ('reply_uname', 'string'),
      },
    ),
  };
  static Map<String, dynamic>? danmaku(String encoded) =>
      decode(encoded, danmakuSchema);
  static Map<String, dynamic>? interaction(String encoded) =>
      decode(encoded, const {
        1: ('uid', 'int'),
        2: ('uname', 'string'),
        5: ('msg_type', 'int'),
        6: ('roomid', 'int'),
        7: ('timestamp', 'int'),
        12: ('contribution', <int, (String, Object)>{1: ('grade', 'int')}),
        16: ('privilege_type', 'int'),
        21: ('is_mystery', 'bool'),
        22: ('uinfo', publicUser),
      });
}
