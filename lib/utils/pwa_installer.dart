// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter/foundation.dart';

import 'pwa_installer_stub.dart'
    if (dart.library.js_interop) 'pwa_installer_web.dart' as impl;

/// Helps install the web app as a PWA on supported browsers (Chrome, Edge, …).
abstract final class PwaInstaller {
  static final ValueNotifier<bool> canInstall = impl.canInstall;

  static void init() => impl.init();

  static bool get isInstalled => impl.isInstalled;

  static Future<void> promptInstall() => impl.promptInstall();
}
