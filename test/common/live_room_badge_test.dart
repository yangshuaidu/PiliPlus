import 'dart:async';

import 'package:PiliPlus/common/widgets/live_room_badge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final parentUsesInk in [false, true]) {
    testWidgets(
      'live badge consumes parent taps and duplicate clicks (ink=$parentUsesInk)',
      (tester) async {
        var parentTaps = 0;
        var lookups = 0;
        final pending = Completer<void>();
        final badge = LiveRoomBadge(
          onOpen: () {
            lookups++;
            return pending.future;
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: parentUsesInk
                    ? InkWell(onTap: () => parentTaps++, child: badge)
                    : GestureDetector(onTap: () => parentTaps++, child: badge),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byType(LiveRoomBadge));
        await tester.pump();
        await tester.tap(find.byType(LiveRoomBadge));
        await tester.pump();
        expect(lookups, 1);
        expect(parentTaps, 0);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        pending.complete();
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.tap(find.byType(LiveRoomBadge));
        await tester.pump();
        expect(lookups, 2);
        expect(parentTaps, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'closing the page during a room lookup does not update disposed state',
    (tester) async {
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LiveRoomBadge(onOpen: () => pending.future)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byType(LiveRoomBadge));
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
