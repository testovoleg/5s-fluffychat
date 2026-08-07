// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat_list/unread_bubble.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/room_status_extension.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:fluffychat/widgets/future_loading_dialog.dart';
import 'package:fluffychat/widgets/hover_builder.dart';
import 'package:fluffychat/widgets/typing_animation.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../../config/themes.dart';
import '../../utils/date_time_extension.dart';
import '../../widgets/avatar.dart';

class ChatListItem extends StatelessWidget {
  final Room room;
  final Room? space;
  final bool activeChat;
  final void Function(BuildContext context)? onLongPress;
  final void Function()? onForget;
  final void Function() onTap;
  final String? filter;

  const ChatListItem(
    this.room, {
    this.activeChat = false,
    required this.onTap,
    this.onLongPress,
    this.onForget,
    this.filter,
    this.space,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isMuted = room.pushRuleState != PushRuleState.notify;
    final typingText = room.getLocalizedTypingText(context);
    final lastEvent = room.lastEvent;
    final ownMessage = lastEvent?.senderId == room.client.userID;
    final directChatMatrixId = room.directChatMatrixID;
    final isDirectChat = directChatMatrixId != null;
    final hasNotifications = room.notificationCount > 0;
    final backgroundColor = activeChat
        ? theme.colorScheme.secondaryContainer
        : null;
    final displayname = room.getLocalizedDisplayname(
      MatrixLocals(L10n.of(context)),
    );
    final filter = this.filter;
    if (filter != null && !displayname.toLowerCase().contains(filter)) {
      return const SizedBox.shrink();
    }

    final needLastEventSender =
        lastEvent != null &&
        room.getState(EventTypes.RoomMember, lastEvent.senderId) == null;
    final space = this.space;
    final spaceBadgeHang = space == null
        ? 0.0
        : (-AppConfig.chatListSpaceBadgeOffset).clamp(
            0.0,
            AppConfig.chatListSpaceBadgeSize,
          );
    final useSpaceBadgeNotch =
        space != null && AppSettings.chatListSpaceBadgeNotch.value;
    final squareBorderRadius = BorderRadius.circular(
      AppConfig.chatListSquareCornerRadius,
    );
    final badgeBorderRadius = BorderRadius.circular(
      AppConfig.chatListSpaceBadgeCornerRadius,
    );

    Widget chatAvatar = Avatar(
      shapeBorder: room.isSpace || space != null
          ? RoundedRectangleBorder(
              borderRadius: squareBorderRadius,
              side: AppConfig.chatListSquareBorderWidth > 0
                  ? BorderSide(
                      width: AppConfig.chatListSquareBorderWidth,
                      color: AppConfig.chatListSquareBorderColor,
                    )
                  : BorderSide.none,
            )
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppConfig.chatListAvatarSize / 2,
              ),
            ),
      borderRadius: room.isSpace || space != null
          ? squareBorderRadius
          : BorderRadius.circular(AppConfig.chatListAvatarSize / 2),
      mxContent: room.avatar,
      size: AppConfig.chatListAvatarSize,
      name: displayname,
      presenceUserId: space == null ? directChatMatrixId : null,
      presenceBackgroundColor: backgroundColor,
      onTap: () => onLongPress?.call(context),
    );

    if (useSpaceBadgeNotch) {
      chatAvatar = ClipPath(
        clipper: _SpaceBadgeNotchClipper(
          squareRadius: AppConfig.chatListSquareCornerRadius,
          badgeSize: AppConfig.chatListSpaceBadgeSize,
          badgeRadius: AppConfig.chatListSpaceBadgeCornerRadius,
          badgeOffset: AppConfig.chatListSpaceBadgeOffset,
          gap: AppConfig.chatListSpaceBadgeNotchWidth,
        ),
        child: chatAvatar,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConfig.chatListItemOuterPadding,
      ),
      child: Material(
        borderRadius: BorderRadius.circular(AppConfig.borderRadius),
        clipBehavior: space != null ? Clip.none : Clip.hardEdge,
        color: backgroundColor,
        child: FutureBuilder(
          future: room.name.isEmpty ? room.loadHeroUsers() : null,
          builder: (context, _) => HoverBuilder(
            builder: (context, listTileHovered) {
              final leading = HoverBuilder(
                builder: (context, hovered) => AnimatedScale(
                  duration: FluffyThemes.animationDuration,
                  curve: FluffyThemes.animationCurve,
                  scale: hovered ? 1.1 : 1.0,
                  child: SizedBox(
                    width: AppConfig.chatListAvatarSize + spaceBadgeHang,
                    height: AppConfig.chatListAvatarSize + spaceBadgeHang,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(left: 0, top: 0, child: chatAvatar),
                        if (space != null)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Avatar(
                              shapeBorder: RoundedRectangleBorder(
                                borderRadius: badgeBorderRadius,
                              ),
                              borderRadius: badgeBorderRadius,
                              mxContent: space.avatar,
                              size: AppConfig.chatListSpaceBadgeSize,
                              name: space.getLocalizedDisplayname(),
                              onTap: () => onLongPress?.call(context),
                            ),
                          ),
                        Positioned(
                          top: 0,
                          right: spaceBadgeHang,
                          child: GestureDetector(
                            onTap: () => onLongPress?.call(context),
                            child: AnimatedScale(
                              duration: FluffyThemes.animationDuration,
                              curve: FluffyThemes.animationCurve,
                              scale: listTileHovered ? 1.0 : 0.0,
                              child: Material(
                                color: backgroundColor,
                                borderRadius: BorderRadius.circular(16),
                                child: const Icon(
                                  Icons.arrow_drop_down_circle_outlined,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              final title = Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      displayname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  if (isMuted)
                    const Padding(
                      padding: EdgeInsets.only(left: 4.0),
                      child: Icon(Icons.notifications_off_outlined, size: 16),
                    ),
                  if (room.isLowPriority)
                    Padding(
                      padding: EdgeInsets.only(
                        right: hasNotifications ? 4.0 : 0.0,
                      ),
                      child: Icon(
                        Icons.low_priority,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  if (room.isFavourite)
                    Padding(
                      padding: EdgeInsets.only(
                        right: hasNotifications ? 4.0 : 0.0,
                      ),
                      child: Icon(
                        Icons.push_pin,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  if (!room.isSpace && room.membership != Membership.invite)
                    Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(
                        room.latestEventReceivedTime.localizedTimeShort(
                          context,
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: room.hasNewMessages
                              ? FontWeight.bold
                              : null,
                          color: room.highlightCount >= 1
                              ? theme.colorScheme.error
                              : room.hasNewMessages
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                    ),
                ],
              );

              final subtitle = Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  if (typingText.isEmpty &&
                      ownMessage &&
                      room.lastEvent?.status.isSending == true) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
                    const SizedBox(width: 4),
                  ],
                  AnimatedSize(
                    clipBehavior: Clip.hardEdge,
                    duration: FluffyThemes.animationDuration,
                    curve: FluffyThemes.animationCurve,
                    child: typingText.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: TypingAnimation(size: 4.0),
                          )
                        : room.lastEvent?.relationshipType ==
                              RelationshipTypes.thread
                        ? Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: theme.colorScheme.outline,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppConfig.borderRadius,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            margin: const EdgeInsets.only(right: 4.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.message_outlined,
                                  size: 12,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  L10n.of(context).thread,
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Expanded(
                    child: DefaultTextStyle(
                      style: theme.textTheme.bodyMedium!.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      child: room.isSpace && room.membership == Membership.join
                          ? Text(
                              L10n.of(context).countChats(
                                room.spaceChildren.where((child) {
                                  final childRoom = room.client.getRoomById(
                                    child.roomId ?? '',
                                  );
                                  return childRoom != null &&
                                      childRoom.membership == Membership.join;
                                }).length,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : typingText.isNotEmpty
                          ? Text(
                              typingText,
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                              ),
                              maxLines: 1,
                              softWrap: false,
                            )
                          : FutureBuilder(
                              key: ValueKey(
                                '${lastEvent?.eventId}_${lastEvent?.type}_${lastEvent?.redacted}',
                              ),
                              future: needLastEventSender
                                  ? lastEvent.calcLocalizedBody(
                                      MatrixLocals(L10n.of(context)),
                                      hideReply: true,
                                      hideEdit: true,
                                      plaintextBody: true,
                                      removeMarkdown: true,
                                      withSenderNamePrefix:
                                          (!isDirectChat ||
                                          directChatMatrixId !=
                                              room.lastEvent?.senderId),
                                    )
                                  : null,
                              initialData: lastEvent?.calcLocalizedBodyFallback(
                                MatrixLocals(L10n.of(context)),
                                hideReply: true,
                                hideEdit: true,
                                plaintextBody: true,
                                removeMarkdown: true,
                                withSenderNamePrefix:
                                    (!isDirectChat ||
                                    directChatMatrixId !=
                                        room.lastEvent?.senderId),
                              ),
                              builder: (context, snapshot) => Text(
                                room.membership == Membership.invite
                                    ? room
                                              .getState(
                                                EventTypes.RoomMember,
                                                room.client.userID!,
                                              )
                                              ?.content
                                              .tryGet<String>('reason') ??
                                          (isDirectChat
                                              ? L10n.of(context).newChatRequest
                                              : L10n.of(
                                                  context,
                                                ).inviteGroupChat)
                                    : snapshot.data?.trim().replaceAll(
                                            '\n',
                                            ' ',
                                          ) ??
                                          L10n.of(context).noMessagesYet,
                                softWrap: false,
                                maxLines: room.notificationCount >= 1 ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  decoration: room.lastEvent?.redacted == true
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  UnreadBubble(room: room),
                ],
              );

              Widget? trailing;
              if (onForget != null) {
                trailing = IconButton(
                  icon: const Icon(Icons.delete_outlined),
                  onPressed: onForget,
                );
              } else if (room.membership == Membership.invite) {
                trailing = IconButton(
                  tooltip: L10n.of(context).declineInvitation,
                  icon: const Icon(Icons.delete_forever_outlined),
                  color: theme.colorScheme.error,
                  onPressed: () async {
                    final consent = await showOkCancelAlertDialog(
                      context: context,
                      title: L10n.of(context).declineInvitation,
                      message: L10n.of(context).areYouSure,
                      okLabel: L10n.of(context).yes,
                      isDestructive: true,
                    );
                    if (consent != OkCancelResult.ok) return;
                    if (!context.mounted) return;
                    await showFutureLoadingDialog(
                      context: context,
                      future: room.leave,
                    );
                  },
                );
              }

              return InkWell(
                onTap: onTap,
                onLongPress: () => onLongPress?.call(context),
                borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: AppConfig.chatListItemMinTileHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConfig.chatListItemContentPadding,
                      vertical: AppConfig.chatListItemMinVerticalPadding,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        leading,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              title,
                              subtitle,
                            ],
                          ),
                        ),
                        ?trailing,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Cuts a soft-square hole at the badge corner so the space badge sits in a
/// cutout instead of using a border/punch-out ring.
class _SpaceBadgeNotchClipper extends CustomClipper<Path> {
  const _SpaceBadgeNotchClipper({
    required this.squareRadius,
    required this.badgeSize,
    required this.badgeRadius,
    required this.badgeOffset,
    required this.gap,
  });

  final double squareRadius;
  final double badgeSize;
  final double badgeRadius;
  final double badgeOffset;
  final double gap;

  @override
  Path getClip(Size size) {
    final outer = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(squareRadius),
        ),
      );

    // Matches Positioned(right/bottom: badgeOffset) for a badge of [badgeSize].
    final left = size.width - badgeOffset - badgeSize;
    final top = size.height - badgeOffset - badgeSize;
    final holeSize = badgeSize + gap * 2;
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left - gap, top - gap, holeSize, holeSize),
          Radius.circular(badgeRadius + gap * 0.5),
        ),
      );

    return Path.combine(PathOperation.difference, outer, hole);
  }

  @override
  bool shouldReclip(covariant _SpaceBadgeNotchClipper oldClipper) =>
      squareRadius != oldClipper.squareRadius ||
      badgeSize != oldClipper.badgeSize ||
      badgeRadius != oldClipper.badgeRadius ||
      badgeOffset != oldClipper.badgeOffset ||
      gap != oldClipper.gap;
}
