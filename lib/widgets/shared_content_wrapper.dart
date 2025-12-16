import 'package:flutter/material.dart';
import 'package:htmlviewer/services/shared_content_manager.dart';

/// A wrapper widget that initializes shared content handling when the app starts
class SharedContentWrapper extends StatefulWidget {
  final Widget child;
  
  const SharedContentWrapper({super.key, required this.child});
  
  @override
  State<SharedContentWrapper> createState() => _SharedContentWrapperState();
}

class _SharedContentWrapperState extends State<SharedContentWrapper> {
  bool _initialized = false;
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Initialize shared content manager when dependencies are ready
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeSharedContent();
      });
    }
  }
  
  void _initializeSharedContent() {
    try {
      // Initialize the shared content manager
      SharedContentManager.initialize(context);
      debugPrint('SharedContentWrapper: Shared content manager initialized');
    } catch (e) {
      debugPrint('SharedContentWrapper: Error initializing shared content: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}