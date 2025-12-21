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
        
        // Handle content:// URIs immediately in onNewIntent
        if (intent.action == Intent.ACTION_VIEW && intent.data != null) {
            val dataString = intent.data.toString()
            if (dataString.startsWith("content://")) {
                println("MainActivity: onNewIntent - Handling content:// URI immediately")
                
                // Try to read the file content from the content URI
                val fileContent = try {
                    readFileContentFromUri(intent.data!!)
                } catch (e: Exception) {
                    println("MainActivity: Error reading content from URI: ${e.message}")
                    null
                }
                
                // Try to get file info
                val fileName = getFileNameFromUri(intent.data!!) ?: "shared_file.html"
                val filePath = getRealPathFromURI(intent.data!!) ?: dataString
                
                // Create a shared data map
                val sharedData = if (fileContent != null) {
                    mapOf(
                        "type" to "file",
                        "content" to fileContent,
                        "fileName" to fileName,
                        "filePath" to filePath,
                        "uri" to dataString
                    )
                } else {
                    mapOf(
                        "type" to "file",
                        "content" to null,
                        "fileName" to fileName,
                        "filePath" to filePath,
                        "uri" to dataString,
                        "error" to "Failed to read content from content URI"
                    )
                }
                
                // Send this to Flutter via the method channel if engine is ready
                if (flutterEngine != null) {
                    try {
                        val channel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, SHARED_CONTENT_CHANNEL)
                        channel.invokeMethod("handleNewSharedContent", sharedData)
                        println("MainActivity: Successfully sent content URI to Flutter via handleNewSharedContent")
                        
                        // Don't store this intent since we've processed it
                        return
                    } catch (e: Exception) {
                        println("MainActivity: Error sending to Flutter, will store for later: ${e.message}")
                    }
                } else {
                    println("MainActivity: Flutter engine not ready, storing intent for later processing")
                }
            }
        }
        
        // Also handle content URIs that come via ACTION_SEND with EXTRA_STREAM
        if (intent.action == Intent.ACTION_SEND && intent.type?.startsWith("text/") == true) {
            val streamUri = intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)
            if (streamUri != null && streamUri.toString().startsWith("content://")) {
                println("MainActivity: onNewIntent - Handling content:// URI from ACTION_SEND")
                
                // Try to read the file content from the content URI
                val fileContent = try {
                    readFileContentFromUri(streamUri)
                } catch (e: Exception) {
                    println("MainActivity: Error reading content from URI: ${e.message}")
                    null
                }
                
                // Try to get file info
                val fileName = getFileNameFromUri(streamUri) ?: "shared_file.html"
                val filePath = getRealPathFromURI(streamUri) ?: streamUri.toString()
                
                // Create a shared data map
                val sharedData = if (fileContent != null) {
                    mapOf(
                        "type" to "file",
                        "content" to fileContent,
                        "fileName" to fileName,
                        "filePath" to filePath,
                        "uri" to streamUri.toString()
                    )
                } else {
                    mapOf(
                        "type" to "file",
                        "content" to null,
                        "fileName" to fileName,
                        "filePath" to filePath,
                        "uri" to streamUri.toString(),
                        "error" to "Failed to read content from content URI"
                    )
                }
                
                // Send this to Flutter via the method channel if engine is ready
                if (flutterEngine != null) {
                    try {
                        val channel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, SHARED_CONTENT_CHANNEL)
                        channel.invokeMethod("handleNewSharedContent", sharedData)
                        println("MainActivity: Successfully sent content URI to Flutter via handleNewSharedContent")
                        
                        // Don't store this intent since we've processed it
                        return
                    } catch (e: Exception) {
                        println("MainActivity: Error sending to Flutter, will store for later: ${e.message}")
                    }
                } else {
                    println("MainActivity: Flutter engine not ready, storing intent for later processing")
                }
            }
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
                    
                    // Check if there's also a stream URI (content URI) for text/html sharing
                    val streamUri = intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)
                    
                    if (streamUri != null && streamUri.toString().startsWith("content://")) {
                        // This is a content URI being shared as text/html
                        println("MainActivity: Detected content URI in text/html sharing")
                        
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
                    } else if (sharedText != null) {
                        // Regular text sharing
                        result.success(mapOf(
                            "type" to "text",
                            "content" to sharedText
                        ))
                    }
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
                    val dataString = data.toString()
                    
                    // Check if this is a content:// URI (Android content provider)
                    if (dataString.startsWith("content://")) {
                        println("MainActivity: Detected content:// URI in ACTION_VIEW")
                        
                        // Try to get file info
                        val fileName = getFileNameFromUri(data) ?: "shared_file.html"
                        val filePath = getRealPathFromURI(data) ?: dataString
                        
                        // Try to read the file content from the content URI
                        val fileContent = try {
                            readFileContentFromUri(data)
                        } catch (e: Exception) {
                            println("MainActivity: Error reading content from URI: ${e.message}")
                            null
                        }
                        
                        if (fileContent != null) {
                            result.success(mapOf(
                                "type" to "file",
                                "content" to fileContent,
                                "fileName" to fileName,
                                "filePath" to filePath,
                                "uri" to dataString
                            ))
                        } else {
                            // Even if we can't read content, provide file info
                            result.success(mapOf(
                                "type" to "file",
                                "content" to null,
                                "fileName" to fileName,
                                "filePath" to filePath,
                                "uri" to dataString,
                                "error" to "Failed to read content from content URI"
                            ))
                        }
                    } else if (dataString.startsWith("http://") || dataString.startsWith("https://")) {
                        // Regular HTTP/HTTPS URL
                        result.success(mapOf(
                            "type" to "url",
                            "content" to dataString
                        ))
                    } else {
                        // Other types of URIs (file://, etc.)
                        result.success(mapOf(
                            "type" to "url",
                            "content" to dataString
                        ))
                    }
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
     * Read file content from a content URI with enhanced error handling
     */
    private fun readFileContentFromUri(uri: Uri): String? {
        try {
            // Special handling for Google Docs encrypted URIs
            val uriString = uri.toString()
            if (uriString.contains("com.google.android.apps.docs.storage") && 
                uriString.contains("enc%3Dencoded")) {
                println("MainActivity: Detected Google Docs encrypted URI, attempting special handling")
                
                // Try to get the actual file path from the encrypted URI
                val realPath = getRealPathFromURI(uri)
                if (realPath != null && !realPath.startsWith("content://")) {
                    // If we can get a real path, try reading from that
                    try {
                        val file = File(realPath)
                        if (file.exists()) {
                            val content = file.readText(Charset.forName("UTF-8"))
                            println("MainActivity: Successfully read Google Docs file from real path: $realPath")
                            return content
                        }
                    } catch (e: Exception) {
                        println("MainActivity: Failed to read Google Docs file from real path: ${e.message}")
                    }
                }
                
                // If we can't get a real path, try the standard content resolver approach
                // but with additional permissions
                return readFileContentFromUriWithPermissions(uri)
            }
            
            // Standard content URI reading for non-Google Docs URIs
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

    /**
     * Read file content from URI with additional permission handling
     */
    private fun readFileContentFromUriWithPermissions(uri: Uri): String? {
        try {
            // Try to get persistent read permissions
            val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                          Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            
            // Check if we have permission
            contentResolver.getPersistedUriPermissions().forEach { permission ->
                if (permission.uri == uri) {
                    println("MainActivity: Already have persisted permissions for URI: $uri")
                    return readFileContentFromUriStandard(uri)
                }
            }
            
            // Request persistent permissions
            try {
                contentResolver.takePersistableUriPermission(uri, takeFlags)
                println("MainActivity: Successfully obtained persistent permissions for URI: $uri")
                return readFileContentFromUriStandard(uri)
            } catch (e: SecurityException) {
                println("MainActivity: Failed to get persistent permissions: ${e.message}")
                // Fall back to temporary permissions
                return readFileContentFromUriStandard(uri)
            }
        } catch (e: Exception) {
            println("MainActivity: Error in permission handling: ${e.message}")
            return null
        }
    }

    /**
     * Standard content URI reading method
     */
    private fun readFileContentFromUriStandard(uri: Uri): String? {
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
                
                // Try UTF-8 first
                try {
                    val content = String(bytes, Charset.forName("UTF-8"))
                    println("MainActivity: Read ${bytes.size} bytes from URI $uri (UTF-8)")
                    return content
                } catch (e: Exception) {
                    println("MainActivity: UTF-8 decoding failed, trying ISO-8859-1")
                    // Fallback to ISO-8859-1 if UTF-8 fails
                    try {
                        val content = String(bytes, Charset.forName("ISO-8859-1"))
                        println("MainActivity: Read ${bytes.size} bytes from URI $uri (ISO-8859-1)")
                        return content
                    } catch (e2: Exception) {
                        println("MainActivity: Both UTF-8 and ISO-8859-1 decoding failed")
                        return null
                    }
                }
            }
        } catch (e: Exception) {
            println("MainActivity: Error reading file content from URI (standard): ${e.message}")
            return null
        }
        
        return null
    }
}
