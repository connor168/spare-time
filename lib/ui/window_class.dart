enum WindowClass { compact, medium, expanded }

WindowClass windowClassFor(double width) {
  if (width < 600) return WindowClass.compact;
  if (width <= 840) return WindowClass.medium;
  return WindowClass.expanded;
}

extension WindowClassLayout on WindowClass {
  bool get usesBottomNavigation => this == WindowClass.compact;

  bool get supportsMultiplePanes => this != WindowClass.compact;

  bool get supportsThreePanes => this == WindowClass.expanded;
}
