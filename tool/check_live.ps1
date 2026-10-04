$ErrorActionPreference = 'Stop'

# Shared by Windows, Android, iOS and the standalone cloud check workflow.
flutter analyze --no-pub --no-fatal-infos `
    lib/http/live.dart lib/models_new/live lib/pages/live_room `
    lib/pages/live_dm_block lib/tcp/live.dart `
    lib/pages/video/widgets/header_mixin.dart `
    lib/plugin/pl_player/controller.dart lib/plugin/pl_player/view/view.dart `
    lib/plugin/pl_player/utils/background_playback_policy.dart `
    lib/services/audio_session.dart lib/pages/setting/models/play_settings.dart `
    lib/services/live_gift_service.dart lib/services/live_red_packet_service.dart `
    lib/services/live_activity_service.dart lib/services/live_superchat_service.dart `
    test
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter test --no-pub --concurrency=1 `
    test/utils/accounts/deleted_account_test.dart `
    test/services/live_gift_service_test.dart `
    test/pages/live_gift_panel_test.dart `
    test/common/live_room_badge_test.dart `
    test/pages/live_messages_test.dart `
    test/pages/live_message_decorations_test.dart `
    test/pages/live_room_features_test.dart `
    test/pages/live_rank_panels_test.dart `
    test/pages/live_red_packet_panel_test.dart `
    test/pages/live_compose_panels_test.dart `
    test/pages/live_settings_test.dart `
    test/pages/live_background_playback_test.dart `
    test/pages/live_mobile_layout_test.dart `
    test/services/live_room_actions_test.dart `
    test/services/live_superchat_service_test.dart
exit $LASTEXITCODE
