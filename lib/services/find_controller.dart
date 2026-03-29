import 'package:flutter/material.dart';

class FindController with ChangeNotifier {
  bool _isActive = false;
  bool _isReplaceMode = false;
  bool _caseSensitive = false;
  bool _matchWholeWord = false;
  bool _isRegex = false;
  int _currentMatchIndex = -1;
  int _matchCount = 0;
  
  final TextEditingController findInputController = TextEditingController();
  final TextEditingController replaceInputController = TextEditingController();
  final FocusNode findInputFocusNode = FocusNode();
  final FocusNode replaceInputFocusNode = FocusNode();
  
  // Note: codeController is not used with Monaco editor
  // final CodeController? codeController;
  
  bool get isActive => _isActive;
  bool get isReplaceMode => _isReplaceMode;
  bool get caseSensitive => _caseSensitive;
  bool get matchWholeWord => _matchWholeWord;
  bool get isRegex => _isRegex;
  int get currentMatchIndex => _currentMatchIndex;
  int get matchCount => _matchCount;
  
  set isActive(bool value) {
    _isActive = value;
    notifyListeners();
  }
  
  set isReplaceMode(bool value) {
    _isReplaceMode = value;
    notifyListeners();
  }
  
  FindController();
  
  void toggleMatchWholeWord() {
    _matchWholeWord = !_matchWholeWord;
    notifyListeners();
  }
  
  void toggleRegex() {
    _isRegex = !_isRegex;
    notifyListeners();
  }
  
  void toggleActive() {
    _isActive = !_isActive;
    if (!_isActive) {
      _isReplaceMode = false;
      _currentMatchIndex = -1;
      _matchCount = 0;
      findInputController.clear();
      replaceInputController.clear();
    }
    notifyListeners();
  }
  
  void toggleReplaceMode() {
    _isReplaceMode = !_isReplaceMode;
    notifyListeners();
  }
  
  void toggleCaseSensitive() {
    _caseSensitive = !_caseSensitive;
    notifyListeners();
  }
  
  void next() {
    if (_matchCount > 0 && _currentMatchIndex < _matchCount - 1) {
      _currentMatchIndex++;
      notifyListeners();
    }
  }
  
  void previous() {
    if (_matchCount > 0 && _currentMatchIndex > 0) {
      _currentMatchIndex--;
      notifyListeners();
    }
  }
  
  void replace() {
    // Implement replace logic
    notifyListeners();
  }
  
  void replaceAll() {
    // Implement replace all logic
    notifyListeners();
  }
  
  void updateMatches(int count, int currentIndex) {
    _matchCount = count;
    _currentMatchIndex = currentIndex;
    notifyListeners();
  }
  
  @override
  void dispose() {
    findInputController.dispose();
    replaceInputController.dispose();
    findInputFocusNode.dispose();
    replaceInputFocusNode.dispose();
    super.dispose();
  }
}