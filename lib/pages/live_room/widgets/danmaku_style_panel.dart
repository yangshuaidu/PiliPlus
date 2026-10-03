import 'package:PiliPlus/models_new/live/live_danmaku_style.dart';
import 'package:material_ui/material_ui.dart';

class LiveDanmakuStylePanel extends StatefulWidget {
  const LiveDanmakuStylePanel({
    super.key,
    required this.config,
    required this.mode,
    required this.color,
  });
  final LiveDanmakuStyleConfig config;
  final int mode, color;
  @override
  State<LiveDanmakuStylePanel> createState() => _LiveDanmakuStylePanelState();
}

class _LiveDanmakuStylePanelState extends State<LiveDanmakuStylePanel> {
  late int mode = widget.mode, color = widget.color;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('弹幕样式'),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('弹幕位置'),
            Wrap(
              spacing: 8,
              children: [
                for (final item in widget.config.modes)
                  ChoiceChip(
                    label: Text(item.name),
                    avatar: item.enabled
                        ? null
                        : const Icon(Icons.lock_outline, size: 14),
                    selected: mode == item.value,
                    onSelected: item.enabled
                        ? (_) => setState(() => mode = item.value)
                        : null,
                  ),
              ],
            ),
            for (final group in widget.config.colors.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 6),
                child: Text(group.key),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in group.value)
                    Tooltip(
                      message:
                          '${item.name}${item.enabled ? '' : ' · 当前账号未解锁'}',
                      child: InkWell(
                        onTap: item.enabled
                            ? () => setState(() => color = item.value)
                            : null,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(0xff000000 | item.value),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == item.value
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                              width: color == item.value ? 3 : 1,
                            ),
                          ),
                          child: item.enabled
                              ? color == item.value
                                    ? const Icon(
                                        Icons.check,
                                        size: 20,
                                        color: Colors.black54,
                                      )
                                    : null
                              : const Icon(
                                  Icons.lock,
                                  size: 15,
                                  color: Colors.black54,
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const Text('锁定状态来自平台。样式用于本次发送。', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: widget.config.permits(mode, color)
            ? () => Navigator.pop(context, (mode: mode, color: color))
            : null,
        child: const Text('应用'),
      ),
    ],
  );
}
