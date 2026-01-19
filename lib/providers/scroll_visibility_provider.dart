import 'package:flutter/material.dart';

/// A provider to manage the visibility of app bar and bottom bar based on scroll direction.
/// This is shared across home_screen and child screens like explore_screen.
class ScrollVisibilityProvider extends ChangeNotifier {
  bool _isVisible = true;

  bool get isVisible => _isVisible;

  void show() {
    if (!_isVisible) {
      _isVisible = true;
      notifyListeners();
    }
  }

  void hide() {
    if (_isVisible) {
      _isVisible = false;
      notifyListeners();
    }
  }

  void setVisible(bool visible) {
    if (_isVisible != visible) {
      _isVisible = visible;
      notifyListeners();
    }
  }
}

/// A mixin that provides scroll-based visibility logic for StatefulWidgets.
/// Add this to any screen that should hide/show bars on scroll.
mixin ScrollVisibilityMixin<T extends StatefulWidget> on State<T> {
  late ScrollController scrollController;
  double _lastScrollOffset = 0;
  static const double _scrollThreshold = 10.0;

  ScrollVisibilityProvider? _scrollVisibilityProvider;

  void initScrollVisibility(ScrollVisibilityProvider provider) {
    _scrollVisibilityProvider = provider;
    scrollController = ScrollController();
    scrollController.addListener(_onScroll);
  }

  void disposeScrollVisibility() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
  }

  void _onScroll() {
    if (_scrollVisibilityProvider == null) return;
    
    final currentOffset = scrollController.offset;
    final delta = currentOffset - _lastScrollOffset;

    if (delta > _scrollThreshold) {
      // Scrolling down - hide bars
      _scrollVisibilityProvider!.hide();
    } else if (delta < -_scrollThreshold) {
      // Scrolling up - show bars
      _scrollVisibilityProvider!.show();
    }

    _lastScrollOffset = currentOffset;
  }
}
