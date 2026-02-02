import 'package:flutter/material.dart';
import 'package:view_source_vibe/services/unified_sharing_service.dart';

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

    // Initialize unified sharing service when dependencies are ready
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeSharedContent();
      });
    }
  }

  void _initializeSharedContent() {
    try {
      UnifiedSharingService.initialize(context);
      debugPrint('SharedContentWrapper: Shared content wrapper ready');
    } catch (e) {
      debugPrint('SharedContentWrapper: Error initializing shared content: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
