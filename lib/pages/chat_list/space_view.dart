// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat_list/empty_chats_placeholder.dart';
import 'package:fluffychat/pages/chat_list/unread_bubble.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/stream_extension.dart';
import 'package:fluffychat/utils/string_color.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/future_loading_dialog.dart';
import 'package:fluffychat/widgets/hover_builder.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

enum SpaceChildAction {
  mute,
  unmute,
  markAsUnread,
  markAsRead,
  removeFromSpace,
  leave,
}

enum SpaceActions { addChild, settings, leave }

class SpaceView extends StatefulWidget {
  final String spaceId;
  final void Function() onBack;
  final void Function(Room room) onChatTab;
  final String? activeChat;

  const SpaceView({
    required this.spaceId,
    required this.onBack,
    required this.onChatTab,
    required this.activeChat,
    super.key,
  });

  @override
  State<SpaceView> createState() => _SpaceViewState();
}

class _SpaceViewState extends State<SpaceView> {
  final List<SpaceRoomsChunk$2> _discoveredChildren = [];
  final TextEditingController _filterController = TextEditingController();
  String? _nextBatch;
  bool _noMoreRooms = false;
  bool _isLoading = false;

  StreamSubscription? _childStateSub;

  @override
  void initState() {
    _loadHierarchy();
    _childStateSub = Matrix.of(context).client.onSync.stream
        .where(
          (syncUpdate) =>
              syncUpdate.rooms?.join?[widget.spaceId]?.timeline?.events?.any(
                (event) => event.type == EventTypes.SpaceChild,
              ) ??
              false,
        )
        .listen(_loadHierarchy);
    super.initState();
  }

  @override
  void dispose() {
    _childStateSub?.cancel();
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _loadHierarchy([_]) async {
    final matrix = Matrix.of(context);
    final room = matrix.client.getRoomById(widget.spaceId);
    if (room == null) return;

    final cacheKey = 'spaces_history_cache${room.id}';
    if (_discoveredChildren.isEmpty) {
      final cachedChildren = matrix.store.getStringList(cacheKey);
      if (cachedChildren != null) {
        try {
          _discoveredChildren.addAll(
            cachedChildren.map(
              (jsonString) =>
                  SpaceRoomsChunk$2.fromJson(jsonDecode(jsonString)),
            ),
          );
        } catch (e, s) {
          Logs().e('Unable to json decode spaces hierarchy cache!', e, s);
          matrix.store.remove(cacheKey);
        }
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final hierarchy = await room.client.getSpaceHierarchy(
        widget.spaceId,
        suggestedOnly: false,
        maxDepth: 2,
        from: _nextBatch,
      );
      if (!mounted) return;
      setState(() {
        if (_nextBatch == null) _discoveredChildren.clear();
        _nextBatch = hierarchy.nextBatch;
        if (hierarchy.nextBatch == null) {
          _noMoreRooms = true;
        }
        _discoveredChildren.addAll(
          hierarchy.rooms.where((room) => room.roomId != widget.spaceId),
        );
        _isLoading = false;
      });

      if (_nextBatch == null) {
        matrix.store.setStringList(
          cacheKey,
          _discoveredChildren
              .map((child) => jsonEncode(child.toJson()))
              .toList(),
        );
      }
    } catch (e, s) {
      Logs().w('Unable to load hierarchy', e, s);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toLocalizedString(context))));
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _joinChildRoom(SpaceRoomsChunk$2 item) async {
    final client = Matrix.of(context).client;
    final space = client.getRoomById(widget.spaceId);
    final via = space?.spaceChildren
        .firstWhereOrNull((child) => child.roomId == item.roomId)
        ?.via;
    final roomResult = await showFutureLoadingDialog(
      context: context,
      future: () async {
        final waitForRoom = client.waitForRoomInSync(item.roomId, join: true);
        await client.joinRoom(item.roomId, via: via);
        await waitForRoom;
        return client.getRoomById(item.roomId)!;
      },
    );
    final room = roomResult.result;
    if (room != null) widget.onChatTab(room);
  }

  Future<void> _onSpaceAction(SpaceActions action) async {
    final space = Matrix.of(context).client.getRoomById(widget.spaceId);

    switch (action) {
      case SpaceActions.settings:
        await space?.postLoad();
        if (!mounted) return;
        context.push('/rooms/${widget.spaceId}/details');
        break;
      case SpaceActions.addChild:
        context.go('/rooms/newgroup?space_id=${widget.spaceId}');
        break;
      case SpaceActions.leave:
        final confirmed = await showOkCancelAlertDialog(
          context: context,
          title: L10n.of(context).areYouSure,
          message: L10n.of(context).archiveRoomDescription,
          okLabel: L10n.of(context).leave,
          cancelLabel: L10n.of(context).cancel,
          isDestructive: true,
        );
        if (!mounted) return;
        if (confirmed != OkCancelResult.ok) return;

        final success = await showFutureLoadingDialog(
          context: context,
          future: () async => await space?.leave(),
        );
        if (!mounted) return;
        if (success.error != null) return;
        widget.onBack();
    }
  }

  Future<void> _showSpaceChildEditMenu(
    BuildContext posContext,
    String roomId,
  ) async {
    final client = Matrix.of(context).client;
    final space = client.getRoomById(widget.spaceId);
    final room = client.getRoomById(roomId);
    if (space == null) return;
    final overlay =
        Overlay.of(posContext).context.findRenderObject() as RenderBox;

    final button = posContext.findRenderObject() as RenderBox;

    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(const Offset(0, -65), ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero) + const Offset(-50, 0),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final action = await showMenu<SpaceChildAction>(
      context: posContext,
      position: position,
      items: [
        if (room != null && room.membership == Membership.join) ...[
          PopupMenuItem(
            value: room.pushRuleState == PushRuleState.notify
                ? SpaceChildAction.mute
                : SpaceChildAction.unmute,
            child: Row(
              mainAxisSize: .min,
              children: [
                Icon(
                  room.pushRuleState == PushRuleState.notify
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_on_outlined,
                ),
                const SizedBox(width: 12),
                Text(
                  room.pushRuleState == PushRuleState.notify
                      ? L10n.of(context).muteChat
                      : L10n.of(context).unmuteChat,
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: room.markedUnread
                ? SpaceChildAction.markAsRead
                : SpaceChildAction.markAsUnread,
            child: Row(
              mainAxisSize: .min,
              children: [
                Icon(
                  room.markedUnread
                      ? Icons.mark_as_unread
                      : Icons.mark_as_unread_outlined,
                ),
                const SizedBox(width: 12),
                Text(
                  room.isUnread
                      ? L10n.of(context).markAsRead
                      : L10n.of(context).markAsUnread,
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: SpaceChildAction.leave,
            child: Row(
              mainAxisSize: .min,
              children: [
                Icon(
                  Icons.delete_outlined,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Text(
                  L10n.of(context).leave,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (space.canChangeStateEvent(EventTypes.SpaceChild) == true)
          PopupMenuItem(
            value: SpaceChildAction.removeFromSpace,
            child: Row(
              mainAxisSize: .min,
              children: [
                Icon(
                  Icons.remove,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Text(
                  L10n.of(context).removeFromSpace,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
    if (action == null) return;
    if (!mounted) return;
    switch (action) {
      case SpaceChildAction.removeFromSpace:
        final consent = await showOkCancelAlertDialog(
          context: context,
          title: L10n.of(context).removeFromSpace,
          message: L10n.of(context).removeFromSpaceDescription,
        );
        if (consent != OkCancelResult.ok) return;
        if (!mounted) return;
        final result = await showFutureLoadingDialog(
          context: context,
          future: () => space.removeSpaceChild(roomId),
        );
        if (result.isError) return;
        if (!mounted) return;
        _nextBatch = null;
        return;
      case SpaceChildAction.mute:
        await showFutureLoadingDialog(
          context: context,
          future: () => room!.setPushRuleState(PushRuleState.mentionsOnly),
        );
      case SpaceChildAction.unmute:
        await showFutureLoadingDialog(
          context: context,
          future: () => room!.setPushRuleState(PushRuleState.notify),
        );
      case SpaceChildAction.markAsUnread:
        await showFutureLoadingDialog(
          context: context,
          future: () => room!.markUnread(true),
        );
      case SpaceChildAction.markAsRead:
        await showFutureLoadingDialog(
          context: context,
          future: () => room!.markUnread(false),
        );
      case SpaceChildAction.leave:
        await showFutureLoadingDialog(
          context: context,
          future: () => room!.leave(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    final room = Matrix.of(context).client.getRoomById(widget.spaceId);
    final displayname =
        room?.getLocalizedDisplayname() ?? l10n.nothingFound;
    final spaceTopic = room?.topic.trim() ?? '';
    const avatarSize = AppConfig.chatListAvatarSize;
    final spaceAvatarBorderRadius = BorderRadius.circular(
      AppConfig.chatListSquareCornerRadius,
    );
    final isAdmin = room?.canChangeStateEvent(EventTypes.SpaceChild) == true;
    return Scaffold(
      body: room == null
          ? const Center(child: Icon(Icons.search_outlined, size: 80))
          : StreamBuilder(
              stream: room.client.onSync.stream
                  .where((s) => s.hasRoomUpdate)
                  .rateLimit(const Duration(seconds: 1)),
              builder: (context, snapshot) {
                final filter = _filterController.text.trim().toLowerCase();
                final filteredChildren = _discoveredChildren.where((item) {
                  final joinedRoom = room.client.getRoomById(item.roomId);
                  final name =
                      item.name ??
                      item.canonicalAlias ??
                      joinedRoom?.getLocalizedDisplayname() ??
                      '';
                  return name.toLowerCase().contains(filter);
                }).toList();
                final showEmptyState =
                    !_isLoading &&
                    filteredChildren.isEmpty &&
                    _noMoreRooms &&
                    filter.isEmpty;

                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      toolbarHeight: 72,
                      floating: true,
                      scrolledUnderElevation: 0,
                      backgroundColor: Colors.transparent,
                      automaticallyImplyLeading: false,
                      title: TextField(
                        controller: _filterController,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(99),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(99),
                            borderSide: BorderSide(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(99),
                            borderSide: BorderSide(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          hintText: l10n.search,
                          hintStyle: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.normal,
                          ),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                          prefixIcon: Icon(
                            Icons.search_outlined,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16 + AppConfig.spaceViewBackIconMargin,
                          4,
                          8,
                          8,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: L10n.of(context).chats,
                              onPressed: widget.onBack,
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                size: AppConfig.spaceViewBackIconSize,
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Avatar(
                              size: avatarSize,
                              mxContent: room.avatar,
                              name: displayname,
                              shapeBorder: RoundedRectangleBorder(
                                borderRadius: spaceAvatarBorderRadius,
                              ),
                              borderRadius: spaceAvatarBorderRadius,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayname,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (spaceTopic.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        spaceTopic,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: l10n.settings,
                              onPressed: () =>
                                  _onSpaceAction(SpaceActions.settings),
                              icon: const Icon(Icons.more_vert),
                            ),
                            if (isAdmin)
                              IconButton(
                                tooltip: l10n.addChatOrSubSpace,
                                onPressed: () =>
                                    _onSpaceAction(SpaceActions.addChild),
                                icon: const Icon(Icons.edit_square),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (showEmptyState)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyChatsPlaceholder(),
                      )
                    else ...[
                      SliverList.builder(
                        itemCount:
                            filteredChildren.length + (_noMoreRooms ? 0 : 1),
                        itemBuilder: (context, i) {
                          if (i == filteredChildren.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 2.0,
                              ),
                              child: TextButton(
                                onPressed: _isLoading ? null : _loadHierarchy,
                                child: _isLoading
                                    ? const CircularProgressIndicator.adaptive()
                                    : Text(l10n.loadMore),
                              ),
                            );
                          }
                          final item = filteredChildren[i];
                          var joinedRoom = room.client.getRoomById(
                            item.roomId,
                          );
                          final childDisplayname =
                              item.name ??
                              item.canonicalAlias ??
                              joinedRoom?.getLocalizedDisplayname() ??
                              l10n.emptyChat;
                          final avatarUrl =
                              item.avatarUrl ?? joinedRoom?.avatar;
                          if (joinedRoom?.membership == Membership.leave) {
                            joinedRoom = null;
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 1,
                            ),
                            child: Material(
                              borderRadius: BorderRadius.circular(
                                AppConfig.borderRadius,
                              ),
                              clipBehavior: Clip.hardEdge,
                              color:
                                  joinedRoom != null &&
                                      widget.activeChat == joinedRoom.id
                                  ? theme.colorScheme.secondaryContainer
                                  : Colors.transparent,
                              child: HoverBuilder(
                                builder: (context, hovered) => ListTile(
                                  visualDensity: const VisualDensity(
                                    vertical: -0.5,
                                  ),
                                  contentPadding: EdgeInsets.only(
                                    left: 8,
                                    right: joinedRoom == null ? 0 : 8,
                                  ),
                                  onTap: joinedRoom != null
                                      ? () => widget.onChatTab(joinedRoom!)
                                      : null,
                                  onLongPress: joinedRoom != null
                                      ? () => _showSpaceChildEditMenu(
                                          context,
                                          item.roomId,
                                        )
                                      : null,
                                  leading:
                                      hovered &&
                                          (isAdmin || joinedRoom != null)
                                      ? SizedBox.square(
                                          dimension: avatarSize,
                                          child: IconButton(
                                            splashRadius: avatarSize,
                                            iconSize: 14,
                                            style: IconButton.styleFrom(
                                              foregroundColor: theme
                                                  .colorScheme
                                                  .onTertiaryContainer,
                                              backgroundColor: theme
                                                  .colorScheme
                                                  .tertiaryContainer,
                                            ),
                                            onPressed: () =>
                                                _showSpaceChildEditMenu(
                                                  context,
                                                  item.roomId,
                                                ),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                        )
                                      : Avatar(
                                          size: avatarSize,
                                          mxContent: avatarUrl,
                                          name: '#',
                                          backgroundColor: theme
                                              .colorScheme
                                              .surfaceContainer,
                                          textColor:
                                              item.name?.colorScheme.primary ??
                                              theme.colorScheme.onSurface,
                                          shapeBorder:
                                              item.roomType == 'm.space'
                                              ? RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        AppConfig
                                                            .chatListSquareCornerRadius,
                                                      ),
                                                )
                                              : null,
                                          borderRadius:
                                              item.roomType == 'm.space'
                                              ? BorderRadius.circular(
                                                  AppConfig
                                                      .chatListSquareCornerRadius,
                                                )
                                              : null,
                                        ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Opacity(
                                          opacity: joinedRoom == null
                                              ? 0.5
                                              : 1,
                                          child: Text(
                                            childDisplayname,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      if (joinedRoom != null &&
                                          joinedRoom.pushRuleState !=
                                              PushRuleState.notify)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 4.0),
                                          child: Icon(
                                            Icons.notifications_off_outlined,
                                            size: 16,
                                          ),
                                        ),
                                      if (joinedRoom != null)
                                        UnreadBubble(room: joinedRoom)
                                      else
                                        TextButton(
                                          onPressed: () =>
                                              _joinChildRoom(item),
                                          child: Text(l10n.join),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (_isLoading && filteredChildren.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: CircularProgressIndicator.adaptive(),
                          ),
                        ),
                      const SliverPadding(padding: EdgeInsets.only(top: 32)),
                    ],
                  ],
                );
              },
            ),
    );
  }
}
