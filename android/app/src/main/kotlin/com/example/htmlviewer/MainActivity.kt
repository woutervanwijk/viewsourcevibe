package info.wouter.sourceviewer

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val SHARED_CONTENT_CHANNEL = "info.wouter.sourceviewer/shared_content"
    private var sharedIntent: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SharingService.registerWith(flutterEngine)
        
        // Setup channel for handling shared content
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARED_CONTENT_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getSharedContent") {
                handleSharedIntent(result)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        sharedIntent = intent
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        sharedIntent = intent
    }

    private fun handleSharedIntent(result: MethodChannel.Result) {
        val intent = sharedIntent ?: run {
            result.success(null)
            return
        }

        when (intent.action) {
            Intent.ACTION_SEND -> {
                if (intent.type?.startsWith("text/") == true) {
                    val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                    result.success(mapOf(
                        "type" to "text",
                        "content" to sharedText
                    ))
                } else if (intent.type?.startsWith("image/") == true) {
                    // Handle image sharing
                    val streamUri = intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)
                    result.success(mapOf(
                        "type" to "image",
                        "uri" to streamUri?.toString()
                    ))
                }
            }
            Intent.ACTION_VIEW -> {
                val data = intent.data
                if (data != null) {
                    result.success(mapOf(
                        "type" to "url",
                        "content" to data.toString()
                    ))
                }
            }
            else -> {
                result.success(null)
            }
        }
        
        // Clear the shared intent after handling
        sharedIntent = null
    }
}
