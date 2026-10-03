import 'package:PiliPlus/pages/live_room/live_gift_effects.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class LiveGiftEffectOverlay extends StatelessWidget {
  const LiveGiftEffectOverlay({super.key, required this.effects});
  final LiveGiftEffects effects;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Obx(() {
      final effect = effects.current.value;
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: effect == null
            ? const SizedBox.shrink()
            : Container(
                key: ObjectKey(effect),
                width: 200,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (effect.url.isNotEmpty)
                      Image.network(
                        effect.url,
                        width: 96,
                        height: 96,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.card_giftcard,
                          color: Colors.amber,
                          size: 48,
                        ),
                      )
                    else
                      const Icon(
                        Icons.card_giftcard,
                        color: Colors.amber,
                        size: 48,
                      ),
                    Text(
                      '${effect.message.name}\n${effect.message.giftName} × ${effect.message.quantity}',
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ],
                ),
              ),
      );
    }),
  );
}
