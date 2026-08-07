// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

final ValueNotifier<bool> canInstall = ValueNotifier(false);

void init() {}

bool get isInstalled => false;

Future<void> promptInstall() async {}
