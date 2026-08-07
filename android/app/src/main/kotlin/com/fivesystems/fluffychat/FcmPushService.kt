package com.fivesystems.fluffychat

import com.famedly.fcm_shared_isolate.FcmSharedIsolateService
import io.flutter.embedding.engine.FlutterEngine

class FcmPushService : FcmSharedIsolateService() {
    override fun getEngine(): FlutterEngine {
        // MainActivity.provideEngine starts Dart when needed and keeps a
        // process-wide cached engine so push can share the isolate with the UI.
        return MainActivity.provideEngine(applicationContext)
    }
}
