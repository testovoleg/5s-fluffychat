// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

extension type _BeforeInstallPromptEvent._(web.Event _) implements web.Event {
  external JSPromise<JSAny?> prompt();
}

final ValueNotifier<bool> canInstall = ValueNotifier(false);

_BeforeInstallPromptEvent? _deferredPrompt;
bool _initialized = false;

void init() {
  if (_initialized) return;
  _initialized = true;

  web.window.addEventListener(
    'beforeinstallprompt',
    (web.Event event) {
      event.preventDefault();
      _deferredPrompt = _BeforeInstallPromptEvent._(event);
      canInstall.value = true;
    }.toJS,
  );

  web.window.addEventListener(
    'appinstalled',
    (web.Event _) {
      _deferredPrompt = null;
      canInstall.value = false;
    }.toJS,
  );
}

bool get isInstalled =>
    web.window.matchMedia('(display-mode: standalone)').matches ||
    web.window.matchMedia('(display-mode: window-controls-overlay)').matches;

Future<void> promptInstall() async {
  final deferred = _deferredPrompt;
  if (deferred == null) return;
  await deferred.prompt().toDart;
  _deferredPrompt = null;
  canInstall.value = false;
}
