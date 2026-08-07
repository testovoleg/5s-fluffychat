// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui';

abstract class AppConfig {
  static const Color primaryColor = Color(0xFF261386);

  static const Color chatColor = primaryColor;
  static const double messageFontSize = 16.0;
  static const bool allowOtherHomeservers = true;
  static const bool enableRegistration = true;
  static const bool hideTypingUsernames = false;

  static const String inviteLinkPrefix = 'https://matrix.to/#/';
  static const String deepLinkPrefix = 'im.fluffychat://chat/';
  static const String schemePrefix = 'matrix:';
  static const String pushNotificationsChannelId = 'fluffychat_push';
  static const String pushNotificationsAppId = 'com.fivesystems.fluffychat';
  static const double borderRadius = 18.0;
  static const double spaceBorderRadius = 11.0;
  static const double columnWidth = 360.0;

  /// Chat list: main avatar (chat or standalone space).
  static const double chatListAvatarSize = 32.0;

  /// Chat list row: outer horizontal padding around the tile.
  static const double chatListItemOuterPadding = 8.0;

  /// Chat list row: ListTile content padding (horizontal).
  static const double chatListItemContentPadding = 8.0;

  /// Chat list row: vertical padding inside each row.
  /// This is the main control for row height (ListTile is not used).
  static const double chatListItemMinVerticalPadding = 8.0;

  /// Chat list row: optional minimum height (0 = hug content).
  static const double chatListItemMinTileHeight = 0.0;

  /// Chat list: corner radius for square avatars (spaces / chats in a space).
  static const double chatListSquareCornerRadius = 8.0;

  /// Chat list: border around the main square avatar.
  static const double chatListSquareBorderWidth = 0.0;
  static const Color chatListSquareBorderColor = Color(0x00000000);

  /// Chat list: space badge on chats in a space (variant D: soft-square outside).
  static const double chatListSpaceBadgeSize = 18.0;

  /// Soft-square corner radius for the space badge.
  static const double chatListSpaceBadgeCornerRadius = 4.0;

  /// Badge offset from avatar corner (negative = outside, right/bottom).
  static const double chatListSpaceBadgeOffset = -6.0;

  /// Notch cutout width (gap between avatar and badge when notch mode is on).
  static const double chatListSpaceBadgeNotchWidth = 2.0;

  /// Legacy border around the badge; keep 0 with soft-square / notch.
  static const double chatListCircleBorderWidth = 0.0;

  /// Transparent = use list-tile background / surface (punched outline).
  static const Color chatListCircleBorderColor = Color(0x00000000);

  /// Spaces navigation rail avatar.
  static const double spaceRailAvatarSize = 32.0;
  static const double spaceRailCornerRadius = 6.0;
  static const double spaceRailSelectionBorderWidth = 2.0;
  static const double spaceRailSelectionGap = 1.0;

  /// Space view: back chevron size next to the space title.
  static const double spaceViewBackIconSize = 8.0;

  /// Space view: horizontal inset shift for the space header
  /// (back chevron, avatar, title). Negative = shift left.
  static const double spaceViewBackIconMargin = -8.0;

  static const String enablePushTutorial =
      'https://fluffychat.im/faq/#push_without_google_services';
  static const String encryptionTutorial =
      'https://fluffychat.im/faq/#how_to_use_end_to_end_encryption';
  static const String startChatTutorial =
      'https://fluffychat.im/faq/#how_do_i_find_other_users';
  static const String howDoIGetStickersTutorial =
      'https://fluffychat.im/faq/#how_do_i_get_stickers';
  static const String appId = 'im.fluffychat.FluffyChat';
  static const String appOpenUrlScheme = 'im.fluffychat';
  static const String appSsoUrlScheme = 'im.fluffychat.auth';
  static const String ssoLogoutUrl =
      'https://login.5systems.ru/realms/5systems/protocol/openid-connect/logout';

  static const String sourceCodeUrl =
      'https://github.com/krille-chan/fluffychat';
  static const String supportUrl =
      'https://github.com/krille-chan/fluffychat/issues';
  static const String changelogUrl = 'https://fluffychat.im/changelog/';
  static const String helpUrl =
      'https://fluffychat.im/faq/#how_can_i_support_fluffychat';

  static const Set<String> defaultReactions = {'👍', '❤️', '😂', '😮', '😢'};

  static final Uri newIssueUrl = Uri(
    scheme: 'https',
    host: 'github.com',
    path: '/krille-chan/fluffychat/issues/new',
  );

  static final Uri homeserverList = Uri(
    scheme: 'https',
    host: 'raw.githubusercontent.com',
    path: 'krille-chan/fluffychat/refs/heads/main/recommended_homeservers.json',
  );

  static const String mainIsolatePortName = 'main_isolate';
  static const String pushIsolatePortName = 'push_isolate';
  static const String pushHelperCrashReportKey = 'push_helper_crash_report';
}
