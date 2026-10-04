import 'package:flutter/widgets.dart' show AppLifecycleState;

enum BackgroundPlaybackAction { none, pause, resume }

/// Lifecycle pauses are separate from user pauses and audio interruptions.
/// Inactive / hidden transitions never resume playback behind another app.
class BackgroundPlaybackPolicy {
  bool _resumeOnForeground = false;
  void cancelResume() => _resumeOnForeground = false;

  BackgroundPlaybackAction handle(
    AppLifecycleState state, {
    required bool continuePlayback,
    required bool playing,
    bool pictureInPicture = false,
  }) {
    if (state == AppLifecycleState.detached) {
      cancelResume();
      return playing
          ? BackgroundPlaybackAction.pause
          : BackgroundPlaybackAction.none;
    }
    if (state == AppLifecycleState.paused) {
      if (!continuePlayback && !pictureInPicture && playing) {
        _resumeOnForeground = true;
        return BackgroundPlaybackAction.pause;
      }
    } else if (state == AppLifecycleState.resumed) {
      final resume = _resumeOnForeground && !playing;
      cancelResume();
      if (resume) return BackgroundPlaybackAction.resume;
    }
    return BackgroundPlaybackAction.none;
  }
}
