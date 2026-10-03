import 'package:PiliPlus/http/live.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/pages/live_room/widgets/danmaku_style_panel.dart';
import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/flutter/text_field/text_field.dart';
import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:PiliPlus/models/common/publish_panel_type.dart';
import 'package:PiliPlus/pages/common/publish/common_rich_text_pub_page.dart';
import 'package:PiliPlus/pages/live_emote/controller.dart';
import 'package:PiliPlus/pages/live_emote/view.dart';
import 'package:PiliPlus/pages/live_room/controller.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart' hide TextField;

class LiveSendDmPanel extends CommonRichTextPubPage {
  final bool fromEmote;
  final LiveRoomController liveRoomController;

  const LiveSendDmPanel({
    super.key,
    super.items,
    super.onSave,
    super.autofocus = true,
    this.fromEmote = false,
    required this.liveRoomController,
  });

  @override
  State<LiveSendDmPanel> createState() => _ReplyPageState();
}

class _ReplyPageState extends CommonRichTextPubPageState<LiveSendDmPanel> {
  bool _sending = false, _loadingStyle = false;
  int _mode = 1, _color = 0xffffff;
  Object? _styleAccount;
  Future<void> _chooseStyle() async {
    if (_loadingStyle) return;
    setState(() => _loadingStyle = true);
    final account = Accounts.main;
    try {
      final config = await LiveHttp.liveDanmakuStyles(
        liveRoomController.roomId,
      );
      if (!mounted || !identical(account, Accounts.main)) return;
      final selected = await showDialog<({int mode, int color})>(
        context: context,
        builder: (_) =>
            LiveDanmakuStylePanel(config: config, mode: _mode, color: _color),
      );
      if (selected != null && mounted && identical(account, Accounts.main)) {
        setState(() {
          _mode = selected.mode;
          _color = selected.color;
          _styleAccount = account;
        });
      }
    } catch (error) {
      SmartDialog.showToast('$error');
    } finally {
      if (mounted) setState(() => _loadingStyle = false);
    }
  }

  LiveRoomController get liveRoomController => widget.liveRoomController;

  @override
  void initState() {
    super.initState();
    if (widget.fromEmote) {
      updatePanelType(PanelType.emoji);
    }
  }

  @override
  void dispose() {
    Get.delete<LiveEmotePanelController>(
      tag: liveRoomController.roomId.toString(),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewSafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 640),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _loadingStyle ? null : _chooseStyle,
                      icon: const Icon(Icons.text_format),
                      label: Text(
                        '样式 · ${const {1: '滚动', 4: '底部', 5: '顶部'}[_mode]}',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _sending
                          ? null
                          : () => liveRoomController.onBuySuperChat(context),
                      icon: const Icon(Icons.paid_outlined),
                      label: const Text('SC'),
                    ),
                  ],
                ),
              ),
              buildInputView(),
              Flexible(child: buildPanelContainer(Colors.transparent)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget? get customPanel => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
    ),
    child: LiveEmotePanel(
      onChoose: onChooseEmote,
      roomId: liveRoomController.roomId,
      onSendEmoticonUnique: (emote) {
        onCustomPublish(
          message: emote.emoticonUnique!,
          dmType: 1,
          emoticonOptions: '[object Object]',
        );
      },
    ),
  );

  Widget buildInputView() {
    return Padding(
      padding: const .only(left: 8, top: 2, right: 8),
      child: Row(
        children: [
          Obx(
            () {
              final isEmoji = panelType.value == .emoji;
              return iconButton(
                tooltip: '表情',
                onPressed: () => updatePanelType(isEmoji ? .keyboard : .emoji),
                iconSize: 22,
                icon: const Icon(Icons.emoji_emotions_outlined),
                iconColor: isEmoji
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(
              () => RichTextField(
                key: key,
                textInputAction: .send,
                controller: editController,
                autofocus: false,
                readOnly: readOnly.value,
                onChanged: onChanged,
                onSubmitted: onSubmitted,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  hintText: "输入弹幕内容",
                  border: InputBorder.none,
                  hintStyle: TextStyle(fontSize: 14),
                ),
                style: theme.textTheme.bodyLarge,
                // inputFormatters: [LengthLimitingTextInputFormatter(20)],
              ),
            ),
          ),
          Obx(
            () => enablePublish.value
                ? iconButton(
                    iconSize: 22,
                    iconColor: theme.colorScheme.onSurfaceVariant,
                    onPressed: () {
                      editController.clear();
                      enablePublish.value = false;
                    },
                    icon: const Icon(Icons.clear),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
          Obx(
            () => iconButton(
              tooltip: '发送',
              iconSize: 22,
              iconColor: enablePublish.value
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              onPressed: enablePublish.value ? onPublishThrottle : null,
              icon: const Icon(Icons.send),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> onCustomPublish({
    String? message,
    List? pictures,
    int? dmType,
    emoticonOptions,
  }) async {
    if (_sending) return;
    if (_styleAccount != null && !identical(_styleAccount, Accounts.main)) {
      setState(() {
        _mode = 1;
        _color = 0xffffff;
        _styleAccount = null;
      });
      SmartDialog.showToast('账号已变化，弹幕样式已重置，请重新确认发送');
      return;
    }
    int replyMid = 0;
    String replyDmid = '';
    if (message == null) {
      final buffer = StringBuffer();
      for (final e in editController.items) {
        if (e.type == .at) {
          replyMid = int.parse(e.rawText);
          replyDmid = e.id!;
        } else {
          buffer.write(e.rawText);
        }
      }
      message = buffer.toString();
    }
    _sending = true;
    final res = await liveRoomController.sendTrackedDanmaku(
      message: message,
      mode: _mode,
      color: _color,
      dmType: dmType,
      emoticonOptions: emoticonOptions,
      replyMid: replyMid,
      replayDmid: replyDmid,
    );
    _sending = false;
    if (!mounted) return;
    if (res.isSuccess) {
      hasPub = true;
      Get.back();
      liveRoomController
        ..savedDanmaku?.clear()
        ..savedDanmaku = null;
      SmartDialog.showToast('接口已接受，正在检测弹幕回显');
    } else {
      res.toast();
    }
  }

  @override
  Future<void>? onMention([bool fromClick = false]) => null;
}
