import 'package:material_ui/material_ui.dart';

class LiveChatLine extends StatelessWidget {
  const LiveChatLine({super.key, required this.content, this.onTap});
  final InlineSpan content;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: const Color(0x70263041),
          borderRadius: BorderRadius.circular(14)),
        child: Text.rich(content,
          style: const TextStyle(fontSize: 15, height: 1.35, color: Colors.white)),
      )),
  );
}
