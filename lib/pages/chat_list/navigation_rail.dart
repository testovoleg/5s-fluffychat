// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/chat_list/navi_rail_item.dart';
import 'package:fluffychat/pages/chat_list/space_rail_order.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/stream_extension.dart';
import 'package:fluffychat/widgets/avatar.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

class SpacesNavigationRail extends StatelessWidget {
  final String? activeSpaceId;
  final void Function() onGoToChats;
  final void Function(String) onGoToSpaceId;
  final VoidCallback? onSpaceOrderChanged;

  const SpacesNavigationRail({
    required this.activeSpaceId,
    required this.onGoToChats,
    required this.onGoToSpaceId,
    this.onSpaceOrderChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (Matrix.of(context).widget.clients.isEmpty) {
      return const SizedBox.shrink();
    }
    final client = Matrix.of(context).client;
    final coloredMode = !FluffyThemes.isColumnMode(context);
    final theme = Theme.of(context);
    return Material(
      color: coloredMode ? theme.colorScheme.surfaceContainer : null,
      child: SafeArea(
        child: StreamBuilder(
          key: ValueKey(client.userID.toString()),
          stream: client.onSync.stream
              .where((s) => s.hasRoomUpdate)
              .rateLimit(const Duration(seconds: 1)),
          builder: (context, _) {
            return _SpacesRailBody(
              client: client,
              activeSpaceId: activeSpaceId,
              onGoToChats: onGoToChats,
              onGoToSpaceId: onGoToSpaceId,
              onSpaceOrderChanged: onSpaceOrderChanged,
            );
          },
        ),
      ),
    );
  }
}

class _SpacesRailBody extends StatefulWidget {
  final Client client;
  final String? activeSpaceId;
  final void Function() onGoToChats;
  final void Function(String) onGoToSpaceId;
  final VoidCallback? onSpaceOrderChanged;

  const _SpacesRailBody({
    required this.client,
    required this.activeSpaceId,
    required this.onGoToChats,
    required this.onGoToSpaceId,
    this.onSpaceOrderChanged,
  });

  @override
  State<_SpacesRailBody> createState() => _SpacesRailBodyState();
}

class _SpacesRailBodyState extends State<_SpacesRailBody> {
  List<String> _orderIds = const [];

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void didUpdateWidget(covariant _SpacesRailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.client.userID != widget.client.userID) {
      setState(_loadOrder);
    }
  }

  void _loadOrder() {
    final userId = widget.client.userID;
    if (userId == null) {
      _orderIds = const [];
      return;
    }
    _orderIds = SpaceRailOrder.load(userId);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final userId = widget.client.userID;
    if (userId == null) return;

    setState(() {
      final ids = List<String>.from(_orderedSpaces().map((s) => s.id));
      final item = ids.removeAt(oldIndex);
      ids.insert(newIndex, item);
      _orderIds = ids;
    });
    await SpaceRailOrder.save(userId, _orderIds);
    widget.onSpaceOrderChanged?.call();
  }

  List<Room> _orderedSpaces() {
    final spaces = widget.client.rooms.where((room) => room.isSpace).toList();
    return SpaceRailOrder.apply(spaces, _orderIds);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const avatarSize = AppConfig.spaceRailAvatarSize;
    const selectionGap = AppConfig.spaceRailSelectionGap;
    const selectionBorderWidth = AppConfig.spaceRailSelectionBorderWidth;
    const innerRadius = AppConfig.spaceRailCornerRadius;
    const outerRadius = innerRadius + selectionGap + selectionBorderWidth;
    final spaceBorderRadius = BorderRadius.circular(innerRadius);
    final selectedBorderRadius = BorderRadius.circular(outerRadius);
    const selectionExtent =
        avatarSize + (selectionGap + selectionBorderWidth) * 2;

    final spaces = _orderedSpaces();
    final isChatsSelected = widget.activeSpaceId == null;
    final railWidth = FluffyThemes.isColumnMode(context)
        ? FluffyThemes.navRailWidth
        : FluffyThemes.navRailWidth + 4;

    return SizedBox(
      width: railWidth,
      child: Column(
        children: [
          NaviRailItem(
            isSelected: isChatsSelected,
            onTap: widget.onGoToChats,
            borderRadius: selectedBorderRadius,
            showSelectionOutline: false,
            icon: SizedBox(
              width: selectionExtent,
              height: selectionExtent,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isChatsSelected)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: selectedBorderRadius,
                          border: Border.all(
                            color: theme.colorScheme.onSurface,
                            width: selectionBorderWidth,
                          ),
                        ),
                      ),
                    ),
                  Icon(
                    isChatsSelected ? Icons.forum : Icons.forum_outlined,
                    size: 22,
                  ),
                ],
              ),
            ),
            toolTip: L10n.of(context).chats,
            unreadBadgeFilter: (room) => true,
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: spaces.length,
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Material(
                      color: Colors.transparent,
                      elevation: 6 * animation.value,
                      child: child,
                    );
                  },
                  child: SizedBox(width: railWidth, child: child),
                );
              },
              onReorderItem: _onReorder,
              itemBuilder: (context, i) {
                final space = spaces[i];
                final displayname = space.getLocalizedDisplayname(
                  MatrixLocals(L10n.of(context)),
                );
                final spaceChildrenIds = space.spaceChildren
                    .map((c) => c.roomId)
                    .toSet();
                final isSpaceSelected = widget.activeSpaceId == space.id;
                // Desktop/web: drag immediately. Mobile: long-press so tap
                // still selects. Avoid Tooltip long-press competing with drag.
                final spaceItem = NaviRailItem(
                  toolTip: displayname,
                  isSelected: isSpaceSelected,
                  onTap: () => widget.onGoToSpaceId(space.id),
                  unreadBadgeFilter: (room) =>
                      spaceChildrenIds.contains(room.id),
                  borderRadius: selectedBorderRadius,
                  showSelectionOutline: false,
                  tooltipTriggerMode: PlatformInfos.isMobile
                      ? TooltipTriggerMode.manual
                      : null,
                  icon: SizedBox(
                    width: selectionExtent,
                    height: selectionExtent,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isSpaceSelected)
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: selectedBorderRadius,
                                border: Border.all(
                                  color: theme.colorScheme.onSurface,
                                  width: selectionBorderWidth,
                                ),
                              ),
                            ),
                          ),
                        Avatar(
                          mxContent: space.avatar,
                          name: displayname,
                          size: avatarSize,
                          shapeBorder: RoundedRectangleBorder(
                            borderRadius: spaceBorderRadius,
                          ),
                          borderRadius: spaceBorderRadius,
                        ),
                      ],
                    ),
                  ),
                );
                if (PlatformInfos.isMobile) {
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(space.id),
                    index: i,
                    child: spaceItem,
                  );
                }
                return ReorderableDragStartListener(
                  key: ValueKey(space.id),
                  index: i,
                  child: spaceItem,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
