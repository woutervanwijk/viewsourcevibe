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
        
        // Update the intent property
        setIntent(intent)
        sharedIntent = intent
        
        // Check if this is a sharing intent or a view intent
        if (intent.action == Intent.ACTION_SEND || intent.action == Intent.ACTION_VIEW) {
            println("MainActivity: onNewIntent - Processing sharing intent")
            
            // Extract data from the intent
            val sharedData = extractSharedData(intent)
            
            if (sharedData != null) {
                // Send to Flutter if engine is ready
                if (flutterEngine != null) {
                    try {
                        val channel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, SHARED_CONTENT_CHANNEL)
                        channel.invokeMethod("handleNewSharedContent", sharedData)
                        println("MainActivity: Successfully sent shared content to Flutter via handleNewSharedContent")
                        
                        // Clear the intent after handling so we don't handle it again on resume
                        sharedIntent = null
                    } catch (e: Exception) {
                        println("MainActivity: Error sending to Flutter: ${e.message}")
                    }
                } else {
                    println("MainActivity: Flutter engine not ready, intent invalid/already waiting")
                }
            }
        }
    }

    private fun handleSharedIntent(result: MethodChannel.Result) {
        val intent = sharedIntent ?: run {
            result.success(null)
            return
        }

        val sharedData = extractSharedData(intent)
        
        if (sharedData != null) {
            result.success(sharedData)
            sharedIntent = null
        } else {
            result.success(null)
        }
    }

    /**
     * unified helper to extract shared data from any intent
     */
    private fun extractSharedData(intent: Intent): Map<String, Any?>? {
        val action = intent.action
        val type = intent.type
        val data = intent.data

        println("MainActivity: extractSharedData - action: $action, type: $type, data: $data")

        if (Intent.ACTION_SEND == action) {
            if (type?.startsWith("text/plain") == true) {
                val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
                return mapOf(
                    "type" to "text",
                    "content" to sharedText
                )
            } else if (type?.startsWith("image/") == true) {
                val streamUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return null
                return mapOf(
                    "type" to "image",
                    "uri" to streamUri.toString()
                )
            } else {
                // Handle generic file sharing or text/html with stream
                val streamUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                
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
                    
                    return mapOf(
                        "type" to "file",
                        "filePath" to filePath,
                        "fileName" to fileName,
                        "uri" to streamUri.toString(),
                        "content" to fileContent
                    )
                } else {
                    // Fallback for any type (including text/html, */*, or null) that has EXTRA_TEXT
                     val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                     if (sharedText != null) {
                         return mapOf(
                            "type" to "text",
                            "content" to sharedText
                        )
                     }
                }
            }
        } else if (Intent.ACTION_VIEW == action) {
            if (data != null) {
                val dataString = data.toString()
                
                // Content URI
                if (dataString.startsWith("content://")) {
                     val fileName = getFileNameFromUri(data) ?: "shared_file.html"
                    val filePath = getRealPathFromURI(data) ?: dataString
                    
                    val fileContent = try {
                        readFileContentFromUri(data)
                    } catch (e: Exception) {
                        null
                    }
                    
                    return mapOf(
                        "type" to "file",
                        "content" to fileContent,
                        "fileName" to fileName,
                        "filePath" to filePath,
                        "uri" to dataString
                    )
                } 
                // HTTP/HTTPS URL - Let the system handling (AppLinks) take care of this
                // We don't want to double-handle it here which causes the "double load" issue
                else if (dataString.startsWith("http://") || dataString.startsWith("https://")) {
                    return null
                }
                // File URI or other
                else {
                    return mapOf(
                        "type" to "url", // Treat as URL/path to be handled by app logic
                        "content" to dataString
                    )
                }
            }
        }
        
        return null
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
