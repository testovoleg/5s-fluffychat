package com.fivesystems.fluffychat

import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor.DartEntrypoint

class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Cached-engine fragments do not auto-start Dart; ensure engine+isolate
        // exist before Fragment restore looks them up in onCreate().
        provideEngine(this)
        super.onCreate(savedInstanceState)
    }

    override fun getCachedEngineId(): String = ENGINE_ID

    override fun shouldDestroyEngineWithHost(): Boolean = false

    companion object {
        const val ENGINE_ID = "fluffychat_engine"

        @JvmField
        var engine: FlutterEngine? = null

        @JvmStatic
        fun provideEngine(context: Context): FlutterEngine {
            FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { cached ->
                engine = cached
                ensureDartExecuting(cached, context)
                return cached
            }

            val eng = FlutterEngine(
                context.applicationContext,
                emptyArray(),
                /* automaticallyRegisterPlugins = */ true,
                /* waitForRestorationData = */ false,
            )
            eng.addEngineLifecycleListener(
                object : FlutterEngine.EngineLifecycleListener {
                    override fun onPreEngineRestart() {}

                    override fun onEngineWillDestroy() {
                        FlutterEngineCache.getInstance().remove(ENGINE_ID)
                        if (engine === eng) {
                            engine = null
                        }
                    }
                },
            )
            FlutterEngineCache.getInstance().put(ENGINE_ID, eng)
            engine = eng
            ensureDartExecuting(eng, context)
            return eng
        }

        private fun ensureDartExecuting(engine: FlutterEngine, context: Context) {
            if (engine.dartExecutor.isExecutingDart) return
            engine.localizationPlugin.sendLocalesToFlutter(
                context.applicationContext.resources.configuration,
            )
            engine.dartExecutor.executeDartEntrypoint(DartEntrypoint.createDefault())
        }
    }
}
