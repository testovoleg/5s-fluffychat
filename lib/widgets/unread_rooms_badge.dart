// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:badges/badges.dart' as b;
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'matrix.dart';

class UnreadRoomsBadge extends StatelessWidget {
  final bool Function(Room) filter;
  final b.BadgePosition? badgePosition;
  final Widget? child;

  const UnreadRoomsBadge({
    super.key,
    required this.filter,
    this.badgePosition,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final unreadCount = Matrix.of(context).client.rooms
        .where(filter)
        .where((r) => (r.isUnread || r.membership == Membership.invite))
        .length;
    return b.Badge(
      badgeStyle: b.BadgeStyle(
        shape: b.BadgeShape.square,
        borderRadius: BorderRadius.circular(8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
        badgeColor: theme.colorScheme.primary,
        elevation: 1,
      ),
      // minWidth keeps single-digit badges round; longer counts become a pill.
      badgeContent: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 7),
        child: Text(
          unreadCount > 99 ? '99+' : unreadCount.toString(),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontSize: 10,
            fontWeight: FontWeight.w500,
            height: 1,
            leadingDistribution: TextLeadingDistribution.even,
          ),
        ),
      ),
      showBadge: unreadCount != 0,
      badgeAnimation: const b.BadgeAnimation.scale(),
      position: badgePosition ?? b.BadgePosition.bottomEnd(),
      child: child,
    );
  }
}
