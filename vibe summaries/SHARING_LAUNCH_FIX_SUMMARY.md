# Sharing Launch Fix Summary

## Problem Statement

When the app was launched from the sharing menu, it would sometimes appear "over" the sharing app rather than opening as a full standalone app. This created a poor user experience where the app didn't feel like a proper standalone application.

## Root Cause

The issue was related to Android's task management and how the app was configured to handle being launched from external sources like the sharing menu. The specific problems were:

1. **Task Affinity**: The app had a custom task affinity (`info.wouter.sourceviewer`) which could cause it to be launched in a separate task stack
2. **Launch Mode**: While `singleTask` is good for normal launches, it needed additional handling for sharing scenarios
3. **Missing Document Launch Mode**: No explicit configuration for how documents should be handled when launched

## Solution Implemented

### 1. AndroidManifest.xml Changes

Modified `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Before -->
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTask"
    android:taskAffinity="info.wouter.sourceviewer"
    ...>

<!-- After -->
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTask"
    android:taskAffinity=""
    android:documentLaunchMode="intoExisting"
    ...>
```

**Changes**:
- Removed custom task affinity (`android:taskAffinity=""`) to use default task affinity
- Added `android:documentLaunchMode="intoExisting"` to ensure documents open in existing app instance

### 2. MainActivity.kt Changes

Enhanced `android/app/src/main/kotlin/com/example/htmlviewer/MainActivity.kt`:

```kotlin
// Added task management logic in onNewIntent
if (!isTaskRoot) {
    println("MainActivity: Not task root, finishing and restarting")
    val newIntent = Intent(this, javaClass)
    newIntent.action = intent.action
    newIntent.data = intent.data
    newIntent.type = intent.type
    newIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
    startActivity(newIntent)
    finish()
    return
}
```

**Purpose**: Ensures the app is properly brought to the front and reset when launched from sharing menu

## Key Changes

### 1. Task Affinity
**Before**: Custom task affinity (`info.wouter.sourceviewer`)
**After**: Default task affinity (`""`)

**Impact**: App now launches in the default task stack, making it behave like a normal app

### 2. Document Launch Mode
**Before**: No explicit document launch mode
**After**: `intoExisting` - documents open in existing app instance

**Impact**: Better handling of file sharing, ensures consistent behavior

### 3. Task Management
**Before**: No special handling for non-root tasks
**After**: Detects and fixes non-root task scenarios

**Impact**: Ensures app always opens properly, even when launched from sharing

## Technical Details

### Task Affinity Explanation
- **Custom Task Affinity**: Causes app to run in its own task stack, which can lead to "over" behavior
- **Default Task Affinity**: Makes app behave like normal apps, launching in the default stack
- **Result**: App opens as a full standalone app, not "over" the sharing app

### Document Launch Mode
- **intoExisting**: Opens documents in the existing app instance
- **intoNew**: Would create a new instance (not what we want)
- **none**: Default behavior
- **Result**: Better handling of shared files and URLs

### Task Root Detection
- `isTaskRoot`: Checks if this activity is the root of its task
- When `false`: App is not the main task, needs to be brought to front properly
- **Result**: Ensures app is always the main task when launched

## Testing

The fix should be tested with various sharing scenarios:

1. **Text Sharing**: Share text from other apps
2. **URL Sharing**: Share URLs from browsers
3. **File Sharing**: Share files from file managers
4. **Google Drive Sharing**: Share files from Google Drive
5. **Multiple Shares**: Share multiple items in sequence

**Expected Behavior**: App should always open as a full standalone app, not "over" the sharing app

## Verification

The fix has been implemented to:
- ✅ Remove custom task affinity that caused "over" behavior
- ✅ Add proper document launch mode for file sharing
- ✅ Add task management logic for non-root scenarios
- ✅ Maintain all existing sharing functionality
- ✅ Ensure app always opens as standalone

## Impact

This fix ensures that:
1. **Better User Experience**: App opens as a proper standalone app
2. **Consistent Behavior**: Works the same whether launched normally or from sharing
3. **Proper Task Management**: Handles Android's task system correctly
4. **Future Compatibility**: Uses standard Android patterns for app launching

The app should now always open in its full context when receiving shared content, providing a much better user experience.