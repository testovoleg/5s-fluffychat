// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/setting_keys.dart';
import 'package:matrix/matrix.dart';

abstract class SpaceRailOrder {
  static String _key(String userId) =>
      'chat.fluffy.space_rail_order.$userId';

  static List<String> load(String userId) =>
      AppSettings.store.getStringList(_key(userId)) ?? const [];

  static Future<void> save(String userId, List<String> orderIds) =>
      AppSettings.store.setStringList(_key(userId), orderIds);

  /// Returns [spaces] sorted by saved order. Unknown ids are dropped;
  /// spaces missing from the saved order are appended in their current order.
  static List<Room> apply(List<Room> spaces, List<String> orderIds) {
    if (spaces.isEmpty) return spaces;
    final byId = {for (final space in spaces) space.id: space};
    final ordered = <Room>[];
    for (final id in orderIds) {
      final space = byId.remove(id);
      if (space != null) ordered.add(space);
    }
    ordered.addAll(byId.values);
    return ordered;
  }
}
