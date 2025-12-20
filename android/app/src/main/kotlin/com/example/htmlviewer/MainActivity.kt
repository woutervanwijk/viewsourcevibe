package info.wouter.sourceviewer

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.charset.Charset

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
        println("MainActivity: onCreate - intent action: ${intent.action}, data: ${intent.data}, type: ${intent.type}")
        if (intent.data != null) {
            println("MainActivity: onCreate - URL detected: ${intent.data}")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        println("MainActivity: onNewIntent called with intent: ${intent.action}")
        println("MainActivity: onNewIntent - data: ${intent.data}, type: ${intent.type}")
        if (intent.data != null) {
            println("MainActivity: onNewIntent - URL detected: ${intent.data}")
        }
        sharedIntent = intent
        // When using singleTask, we need to explicitly set the intent
        // to ensure it's processed when the activity is brought to front
        setIntent(intent)
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
                } else {
                    // Handle file sharing - check for EXTRA_STREAM
                    val streamUri = intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)
                    if (streamUri != null) {
                        // Try to get the actual file path from the content URI
                        val filePath = getRealPathFromURI(streamUri)
                        val fileName = getFileNameFromUri(streamUri)
                        
                        // Try to read the file content directly
                        val fileContent = try {
                            readFileContentFromUri(streamUri)
                        } catch (e: Exception) {
                            println("MainActivity: Error reading file content: ${e.message}")
                            null
                        }
                        
                        result.success(mapOf(
                            "type" to "file",
                            "filePath" to filePath,
                            "fileName" to fileName,
                            "uri" to streamUri.toString(),
                            "content" to fileContent
                        ))
                    }
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

    /**
     * Get the real file path from a content URI
     */
    private fun getRealPathFromURI(uri: Uri): String? {
        var path: String? = null
        val projection = arrayOf(android.provider.MediaStore.Images.Media.DATA)
        
        try {
            val cursor = contentResolver.query(uri, projection, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val columnIndex = it.getColumnIndexOrThrow(projection[0])
                    path = it.getString(columnIndex)
                }
            }
        } catch (e: Exception) {
            println("MainActivity: Error getting real path from URI: ${e.message}")
            // If we can't get the real path, return the URI string as fallback
            path = uri.toString()
        }
        
        println("MainActivity: Real path for URI $uri is $path")
        return path
    }

    /**
     * Get file name from a content URI
     */
    private fun getFileNameFromUri(uri: Uri): String? {
        var fileName: String? = null
        
        try {
            val cursor = contentResolver.query(uri, null, null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val nameIndex = it.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (nameIndex != -1) {
                        fileName = it.getString(nameIndex)
                    }
                }
            }
        } catch (e: Exception) {
            println("MainActivity: Error getting file name from URI: ${e.message}")
        }
        
        // Fallback: try to get file name from path
        if (fileName == null) {
            fileName = uri.lastPathSegment
        }
        
        println("MainActivity: File name for URI $uri is $fileName")
        return fileName
    }

    /**
     * Read file content from a content URI
     */
    private fun readFileContentFromUri(uri: Uri): String? {
        try {
            val inputStream = contentResolver.openInputStream(uri)
            inputStream?.use { stream ->
                val buffer = ByteArray(1024)
                val outputStream = ByteArrayOutputStream()
                var bytesRead: Int
                
                while (stream.read(buffer).also { bytesRead = it } != -1) {
                    outputStream.write(buffer, 0, bytesRead)
                }
                
                val bytes = outputStream.toByteArray()
                val content = String(bytes, Charset.forName("UTF-8"))
                
                println("MainActivity: Read ${bytes.size} bytes from URI $uri")
                return content
            }
        } catch (e: Exception) {
            println("MainActivity: Error reading file content from URI: ${e.message}")
            return null
        }
        
        return null
    }
}
