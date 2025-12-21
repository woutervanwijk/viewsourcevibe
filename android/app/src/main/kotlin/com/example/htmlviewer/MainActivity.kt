package info.wouter.sourceviewer

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
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
                val sharedData = mutableMapOf(
                    "type" to "file",
                    "content" to fileContent,
                    "fileName" to fileName,
                    "filePath" to filePath,
                    "uri" to dataString
                )
                
                if (fileContent == null) {
                    sharedData["error"] = "Failed to read content from content URI. See logs for details."
                    // Include the last error if we can track it
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
            println("MainActivity: Starting to read content from URI: $uri")
            
            // 1. Try standard reading first (most common for regular files)
            var content = readFileContentFromUriStandard(uri)
            if (content != null) return content
            
            // 2. Try as a "virtual" file if it's a Google Doc/Sheet
            content = readVirtualFile(uri)
            if (content != null) return content
            
            // 3. Try with persistent permissions attempt
            val uriString = uri.toString()
            if (uriString.contains("com.google.android.apps.docs")) {
                println("MainActivity: Standard read failed for Google URI, trying with permissions")
                return readFileContentFromUriWithPermissions(uri)
            }
        } catch (e: Exception) {
            println("MainActivity: Error in readFileContentFromUri: ${e.message}")
        }
        
        return null
    }

    /**
     * Handles Google Drive "Virtual" files by attempting to export them to text or HTML
     */
    private fun readVirtualFile(uri: Uri): String? {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            try {
                // Check if it's a virtual file
                val cursor = contentResolver.query(uri, null, null, null, null)
                var isVirtual = false
                cursor?.use {
                    if (it.moveToFirst()) {
                        val index = it.getColumnIndex("is_virtual")
                        if (index != -1) {
                            isVirtual = it.getInt(index) != 0
                        }
                    }
                }
                
                if (isVirtual) {
                    println("MainActivity: Detected virtual file, attempting export")
                    // Try to export as text/html first, then plain text
                    val types = contentResolver.getStreamTypes(uri, "*/*") ?: emptyArray()
                    val targetType = when {
                        types.contains("text/html") -> "text/html"
                        types.contains("text/plain") -> "text/plain"
                        types.isNotEmpty() && types[0].startsWith("text/") -> types[0]
                        else -> null
                    }
                    
                    if (targetType != null) {
                        println("MainActivity: Exporting virtual file as $targetType")
                        contentResolver.openTypedAssetFileDescriptor(uri, targetType, null)?.use { afd ->
                            afd.createInputStream().use { stream ->
                                return stream.bufferedReader().readText()
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                println("MainActivity: Error reading virtual file: ${e.message}")
            }
        }
        return null
    }

    /**
     * Read file content from URI with additional permission handling
     */
    private fun readFileContentFromUriWithPermissions(uri: Uri): String? {
        try {
            // Try to get persistent read permissions if possible
            val takeFlags = Intent.FLAG_GRANT_READ_URI_PERMISSION
            
            try {
                contentResolver.takePersistableUriPermission(uri, takeFlags)
                println("MainActivity: Obtained persistent permissions for URI: $uri")
            } catch (e: SecurityException) {
                println("MainActivity: Could not obtain persistent permissions: ${e.message}")
            }
            
            // Try reading again after permission attempt
            return readFileContentFromUriStandard(uri)
        } catch (e: Exception) {
            println("MainActivity: Error in permission handling: ${e.message}")
            return null
        }
    }

    /**
     * Standard content URI reading method with robust stream handling
     */
    private fun readFileContentFromUriStandard(uri: Uri): String? {
        try {
            println("MainActivity: Opening input stream for URI: $uri")
            // Try openInputStream first
            val inputStream = try {
                contentResolver.openInputStream(uri)
            } catch (e: Exception) {
                println("MainActivity: openInputStream failed, will try FD: ${e.message}")
                null
            }

            if (inputStream != null) {
                inputStream.use { stream ->
                    val buffer = ByteArray(1024 * 16) // 16KB buffer
                    val outputStream = ByteArrayOutputStream()
                    var bytesRead: Int
                    
                    while (stream.read(buffer).also { bytesRead = it } != -1) {
                        outputStream.write(buffer, 0, bytesRead)
                    }
                    
                    val bytes = outputStream.toByteArray()
                    println("MainActivity: Successfully read ${bytes.size} bytes from URI: $uri")
                    
                    if (bytes.isEmpty()) return ""

                    try {
                        return String(bytes, Charset.forName("UTF-8"))
                    } catch (e: Exception) {
                        return String(bytes, Charset.forName("ISO-8859-1"))
                    }
                }
            }

            // Fallback: Try openFileDescriptor
            println("MainActivity: Attempting openFileDescriptor for URI: $uri")
            contentResolver.openFileDescriptor(uri, "r")?.use { pfd ->
                java.io.FileInputStream(pfd.fileDescriptor).use { fis ->
                    return fis.bufferedReader().readText()
                }
            }
        } catch (e: SecurityException) {
            println("MainActivity: SecurityException reading URI $uri: ${e.message}")
        } catch (e: Exception) {
            println("MainActivity: Error reading URI $uri: ${e.message}")
        }
        
        return null
    }
}
