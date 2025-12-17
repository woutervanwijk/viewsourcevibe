package com.example.htmlviewer

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Environment
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileWriter

class SharingService : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.htmlviewer.sharing")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "shareText" -> shareText(call, result)
            "shareHtml" -> shareHtml(call, result)
            "shareFile" -> shareFile(call, result)
            else -> result.notImplemented()
        }
    }

    private fun shareText(call: MethodCall, result: Result) {
        val text = call.argument<String>("text")
        
        if (text == null) {
            result.error("INVALID_ARGUMENTS", "Text argument is required", null)
            return
        }
        
        val intent = Intent().apply {
            action = Intent.ACTION_SEND
            putExtra(Intent.EXTRA_TEXT, text)
            type = "text/plain"
        }
        
        val shareIntent = Intent.createChooser(intent, "Share Text")
        shareIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        
        try {
            context.startActivity(shareIntent)
            result.success(true)
        } catch (e: Exception) {
            result.error("SHARE_FAILED", "Failed to share text: ${e.message}", null)
        }
    }

    private fun shareHtml(call: MethodCall, result: Result) {
        val html = call.argument<String>("html")
        val filename = call.argument<String>("filename") ?: "shared_content.html"
        
        if (html == null) {
            result.error("INVALID_ARGUMENTS", "HTML argument is required", null)
            return
        }
        
        try {
            // Create a temporary file in the app's cache directory
            // This is more reliable than using DOCUMENTS directory
            val cacheDir = context.cacheDir
            val tempFile = File(cacheDir, filename)
            FileWriter(tempFile).use { writer ->
                writer.write(html)
            }
            
            // Use FileProvider for proper file sharing permissions
            val uri = try {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                    // Use FileProvider for Android 7.0+ to avoid file exposure warnings
                    val authority = "${context.packageName}.fileprovider"
                    println("SharingService: Using FileProvider with authority: $authority, file: ${tempFile.absolutePath}")
                    FileProvider.getUriForFile(context, authority, tempFile)
                } else {
                    println("SharingService: Using direct file URI (pre-Nougat)")
                    Uri.fromFile(tempFile)
                }
            } catch (e: IllegalArgumentException) {
                println("SharingService: FileProvider error - file not in allowed paths: ${e.message}")
                // Fallback to direct file URI if FileProvider fails
                Uri.fromFile(tempFile)
            }
            
            val intent = Intent().apply {
                action = Intent.ACTION_SEND
                putExtra(Intent.EXTRA_STREAM, uri)
                type = "text/html"
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            
            val shareIntent = Intent.createChooser(intent, "Share HTML")
            shareIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            
            context.startActivity(shareIntent)
            result.success(true)
        } catch (e: Exception) {
            result.error("SHARE_FAILED", "Failed to share HTML: ${e.message}", null)
        }
    }

    private fun shareFile(call: MethodCall, result: Result) {
        val filePath = call.argument<String>("filePath")
        val mimeType = call.argument<String>("mimeType") ?: "text/html"
        
        if (filePath == null) {
            result.error("INVALID_ARGUMENTS", "filePath argument is required", null)
            return
        }
        
        val file = File(filePath)
        
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "File not found at path: $filePath", null)
            return
        }
        
        // Use FileProvider for proper file sharing permissions
        val uri = try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                val authority = "${context.packageName}.fileprovider"
                println("SharingService: Using FileProvider for file sharing with authority: $authority, file: ${file.absolutePath}")
                FileProvider.getUriForFile(context, authority, file)
            } else {
                println("SharingService: Using direct file URI for file sharing (pre-Nougat)")
                Uri.fromFile(file)
            }
        } catch (e: IllegalArgumentException) {
            println("SharingService: FileProvider error for file sharing - file not in allowed paths: ${e.message}")
            // Fallback to direct file URI if FileProvider fails
            Uri.fromFile(file)
        }
        
        val intent = Intent().apply {
            action = Intent.ACTION_SEND
            putExtra(Intent.EXTRA_STREAM, uri)
            type = mimeType
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        
        val shareIntent = Intent.createChooser(intent, "Share File")
        shareIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        
        try {
            context.startActivity(shareIntent)
            result.success(true)
        } catch (e: Exception) {
            result.error("SHARE_FAILED", "Failed to share file: ${e.message}", null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
    
    companion object {
        fun registerWith(flutterEngine: FlutterEngine) {
            flutterEngine.plugins.add(SharingService())
        }
    }
}