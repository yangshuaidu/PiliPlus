import 'package:PiliPlus/plugin/pl_player/utils/background_playback_policy.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live audio survives the iOS lock and Android background lifecycle', () {
    for (final states in [
      [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ],
      [AppLifecycleState.inactive, AppLifecycleState.paused],
    ]) {
      final policy = BackgroundPlaybackPolicy();
      for (final state in [
        ...states,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        expect(
          policy.handle(state, continuePlayback: true, playing: true),
          BackgroundPlaybackAction.none,
        );
      }
    }
  });
  test(
    'disabled background audio resumes only after a real foreground return',
    () {
      final policy = BackgroundPlaybackPolicy();
      expect(
        policy.handle(
          AppLifecycleState.paused,
          continuePlayback: false,
          playing: true,
        ),
        BackgroundPlaybackAction.pause,
      );
      for (final state in [
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
      ]) {
        expect(
          policy.handle(state, continuePlayback: false, playing: false),
          BackgroundPlaybackAction.none,
        );
      }
      expect(
        policy.handle(
          AppLifecycleState.resumed,
          continuePlayback: false,
          playing: false,
        ),
        BackgroundPlaybackAction.resume,
      );
      expect(
        policy.handle(
          AppLifecycleState.resumed,
          continuePlayback: false,
          playing: false,
        ),
        BackgroundPlaybackAction.none,
      );
    },
  );
  test('user pauses and audio interruptions cancel lifecycle auto resume', () {
    final policy = BackgroundPlaybackPolicy();
    policy.handle(
      AppLifecycleState.paused,
      continuePlayback: false,
      playing: true,
    );
    policy.cancelResume();
    expect(
      policy.handle(
        AppLifecycleState.resumed,
        continuePlayback: false,
        playing: false,
      ),
      BackgroundPlaybackAction.none,
    );
    policy.handle(
      AppLifecycleState.paused,
      continuePlayback: false,
      playing: false,
    );
    expect(
      policy.handle(
        AppLifecycleState.resumed,
        continuePlayback: true,
        playing: false,
      ),
      BackgroundPlaybackAction.none,
    );
  });
  test(
    'Android picture in picture keeps playing even with background audio off',
    () {
      final policy = BackgroundPlaybackPolicy();
      expect(
        policy.handle(
          AppLifecycleState.paused,
          continuePlayback: false,
          playing: true,
          pictureInPicture: true,
        ),
        BackgroundPlaybackAction.none,
      );
      expect(
        policy.handle(
          AppLifecycleState.resumed,
          continuePlayback: false,
          playing: true,
        ),
        BackgroundPlaybackAction.none,
      );
    },
  );
  test('detach cancels any resume and stops the detached player', () {
    final policy = BackgroundPlaybackPolicy();
    expect(
      policy.handle(
        AppLifecycleState.detached,
        continuePlayback: true,
        playing: true,
      ),
      BackgroundPlaybackAction.pause,
    );
    expect(
      policy.handle(
        AppLifecycleState.resumed,
        continuePlayback: true,
        playing: false,
      ),
      BackgroundPlaybackAction.none,
    );
  });
}
