// Adapted from z1braaa/PiliPlus PR #3145 (1f20ad3), GPL-3.0.
// Gift-only models and parsing; unrelated live enhancements are not included.
int? liveInt(Object? value) => switch (value) {
  int v => v,
  num v when v.isFinite && v == v.roundToDouble() => v.toInt(),
  String v => int.tryParse(v),
  _ => null,
};

Map<String, dynamic> liveMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> liveMaps(Object? value) => value is List
    ? value.whereType<Map>().map(liveMap).toList(growable: false)
    : const [];

bool? liveBool(Object? value) => switch (value) {
  bool v => v,
  1 || '1' => true,
  0 || '0' => false,
  _ => null,
};

/// Display conversion only; API requests and balance checks retain raw gold.
String liveBatteryAmount(int gold) {
  if (gold < 0) return '-${liveBatteryAmount(-gold)}';
  final whole = gold ~/ 100;
  final fraction = (gold % 100).toString().padLeft(2, '0');
  return fraction == '00'
      ? '$whole'
      : '$whole.${fraction.replaceFirst(RegExp(r'0$'), '')}';
}

enum LiveActionState { notSubmitted, submitting, succeeded, failed, unknown }

class LiveGift {
  final int id;
  final String name;

  /// Official integer gold/silver units. No assumed RMB conversion.
  final int price;
  final bool priceKnown;
  final String coinType;
  final String imageUrl;
  final String description;
  final int maxQuantity;
  final List<int>? allowedQuantities;
  final bool sendable;
  final String? unavailableReason;

  const LiveGift({
    required this.id,
    required this.name,
    required this.price,
    required this.coinType,
    this.priceKnown = true,
    this.imageUrl = '',
    this.description = '',
    this.maxQuantity = 1,
    this.allowedQuantities,
    this.sendable = false,
    this.unavailableReason,
  });

  String formatPrice(int raw) =>
      coinType == 'gold' ? liveBatteryAmount(raw) : '$raw';
  String get displayPrice => formatPrice(price);

  String get coinLabel => switch (coinType) {
    'gold' => '电池',
    'silver' => '银瓜子',
    _ => coinType,
  };
}

class LiveBagItem {
  final int bagId;
  final int giftId;
  final String name;
  final int quantity;
  final DateTime? expiresAt;
  final LiveGift gift;
  final bool available;
  const LiveBagItem({
    required this.bagId,
    required this.giftId,
    required this.name,
    required this.quantity,
    required this.gift,
    required this.available,
    this.expiresAt,
  });
}

class LiveWallet {
  final int? gold;
  const LiveWallet({this.gold});
}

/// Membership comes from the room catalogue, not inferred from gift names.
class LiveGiftGroup {
  final String id;
  final String name;
  final Set<int> giftIds;
  const LiveGiftGroup({
    required this.id,
    required this.name,
    required this.giftIds,
  });
}

class LiveGiftSnapshot {
  final Object accountIdentity;
  final int accountUid;
  final List<LiveGift> gifts;
  final List<LiveGiftGroup> groups;
  final List<LiveBagItem> bag;
  final LiveWallet wallet;
  final Map<String, String> errors;
  const LiveGiftSnapshot({
    required this.accountIdentity,
    required this.accountUid,
    required this.gifts,
    this.groups = const [],
    required this.bag,
    required this.wallet,
    required this.errors,
  });
}

class LiveGiftConfirmation {
  final LiveGift gift;
  final int quantity;
  final LiveBagItem? bagItem;
  final int accountUid;
  final int roomId;
  final int anchorUid;
  final Object accountIdentity;
  final DateTime expiresAt;
  final String operationId;
  const LiveGiftConfirmation({
    required this.gift,
    required this.quantity,
    required this.accountUid,
    required this.roomId,
    required this.anchorUid,
    required this.accountIdentity,
    required this.expiresAt,
    required this.operationId,
    this.bagItem,
  });
  int get totalPrice => bagItem == null ? gift.price * quantity : 0;
  String get displayTotalPrice => liveBatteryAmount(totalPrice);
}

class LiveGiftResult {
  final LiveActionState state;
  final String message;
  final String operationId;
  final String? receiptId;
  const LiveGiftResult(
    this.state,
    this.message,
    this.operationId, {
    this.receiptId,
  });
}

class LiveGiftException implements Exception {
  final String message;
  const LiveGiftException(this.message);
  @override
  String toString() => message;
}
