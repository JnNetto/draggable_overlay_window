/// A floating overlay window that can be dragged, resized, minimized,
/// and maximized.
///
/// Place one or more [DraggableOverlayWindow] widgets in an
/// [OverlayWindowStack]. Drive each window with a [DraggableWindowController]
/// and tune appearance and motion through [DraggableWindowConfig].
///
/// * Drag the header, or the content when the header is hidden.
/// * Resize from the edges and corners. Width and height can be enabled
///   independently, or resizing can be turned off.
/// * Minimize and restore. [DraggableOverlayWindow.onMinimized] and
///   [DraggableOverlayWindow.onRestored] report those header actions.
/// * Maximize to the largest allowed size, then restore with a small inset
///   so the resize edges stay reachable.
/// * Animate open, close, minimize, restore, maximize, and unmaximize
///   separately via [DraggableWindowAnimations].
/// * Hide the window from its header or from the controller.
/// * Click a window to focus it. [WindowManager] keeps the stacking order.
/// * The window keeps its state while minimized.
/// * Each [DraggableOverlayWindow] requires a [Key].
library;

import 'dart:async';

import 'package:flutter/material.dart';

// ============================================================================
// WINDOW MANAGER (z-order and focus)
// ============================================================================

/// Shared registry of overlay windows and their stacking order.
///
/// Every visible [DraggableOverlayWindow] registers here. The last id in
/// [windowStack] is the focused window, and [OverlayWindowStack] paints it
/// above the others.
///
/// This type is a singleton. [WindowManager.new] always returns the same
/// instance.
class WindowManager extends ChangeNotifier {
  static final WindowManager _instance = WindowManager._internal();

  /// Returns the shared [WindowManager].
  factory WindowManager() => _instance;

  WindowManager._internal();

  final List<String> _windowStack = [];
  int _nextId = 0;

  /// Returns a new unique window id.
  String generateId() {
    return 'window_${_nextId++}';
  }

  final Map<String, String> _taggedWindows = {};

  /// Registers [windowId] and notifies listeners when the id is new.
  ///
  /// When [tag] is set, [getWindowIdByTag] later returns this id. If [tag]
  /// already points at another window, it is updated to [windowId].
  void registerWindow(String windowId, {String? tag}) {
    if (tag != null) {
      _taggedWindows[tag] = windowId;
    }

    if (!_windowStack.contains(windowId)) {
      _windowStack.add(windowId);
      notifyListeners();
    }
  }

  /// Removes [windowId] and any tag that pointed at it.
  ///
  /// Notifies listeners only when [windowId] was registered.
  void unregisterWindow(String windowId) {
    final wasRegistered = _windowStack.remove(windowId);
    _taggedWindows.removeWhere((key, value) => value == windowId);
    if (wasRegistered) notifyListeners();
  }

  /// Returns the window id registered with [tag], or null when [tag] is unused.
  String? getWindowIdByTag(String tag) {
    return _taggedWindows[tag];
  }

  /// Moves [windowId] to the top of the stack, making it the focused window.
  ///
  /// Does nothing when [windowId] is unknown or already on top.
  void bringToFront(String windowId) {
    if (_windowStack.isNotEmpty && _windowStack.last == windowId) return;
    if (_windowStack.remove(windowId)) {
      _windowStack.add(windowId);
      notifyListeners();
    }
  }

  /// Returns the stacking index of [windowId].
  ///
  /// Higher values are painted above lower ones. Returns `-1` when
  /// [windowId] is not registered.
  int getZIndex(String windowId) {
    return _windowStack.indexOf(windowId);
  }

  /// Whether [windowId] is the focused window, currently last in the stack.
  bool isOnTop(String windowId) {
    return _windowStack.isNotEmpty && _windowStack.last == windowId;
  }

  /// Window ids from back to front.
  ///
  /// The last id is the focused window. The list is unmodifiable.
  List<String> get windowStack => List.unmodifiable(_windowStack);
}

// ============================================================================
// ANIMATIONS
// ============================================================================

/// Motion for one window action, such as open, minimize, or maximize.
///
/// Use [instant] when that action should not animate. Pass an instance to
/// [DraggableWindowAnimations] to override a single action.
class WindowTransitionStyle {
  /// How long this transition runs.
  ///
  /// [Duration.zero] disables the animation.
  final Duration duration;

  /// Easing curve applied while the transition runs.
  final Curve curve;

  /// Opacity at the start, from 0 (invisible) to 1 (opaque).
  final double beginOpacity;

  /// Opacity at the end, from 0 (invisible) to 1 (opaque).
  final double endOpacity;

  /// Scale at the start. `1` is the window's normal size.
  final double beginScale;

  /// Scale at the end. `1` is the window's normal size.
  final double endScale;

  /// Origin the scale animation grows from.
  ///
  /// For example, [Alignment.topCenter] makes a minimize animation shrink
  /// toward the header.
  final Alignment scaleAlignment;

  /// Whether position and size are interpolated.
  ///
  /// Turn this on for minimize, restore, maximize, and unmaximize. When
  /// false, only opacity and scale change.
  final bool animateRect;

  /// Creates a transition.
  ///
  /// A [duration] of [Duration.zero] skips the animation. [beginOpacity] and
  /// [endOpacity] control the fade. [beginScale] and [endScale] control the
  /// zoom around [scaleAlignment]. [animateRect] also interpolates position
  /// and size. [curve] eases the whole transition.
  const WindowTransitionStyle({
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
    this.beginOpacity = 1,
    this.endOpacity = 1,
    this.beginScale = 1,
    this.endScale = 1,
    this.scaleAlignment = Alignment.center,
    this.animateRect = true,
  });

  /// A transition that finishes immediately, with no visible animation.
  static const WindowTransitionStyle instant = WindowTransitionStyle(
    duration: Duration.zero,
  );

  /// Returns a copy with the given properties replaced.
  ///
  /// A null argument keeps the current value. Each parameter matches the
  /// field of the same name.
  WindowTransitionStyle copyWith({
    /// How long this transition runs. [Duration.zero] disables it.
    Duration? duration,

    /// Easing curve applied while the transition runs.
    Curve? curve,

    /// Opacity at the start, from 0 (invisible) to 1 (opaque).
    double? beginOpacity,

    /// Opacity at the end, from 0 (invisible) to 1 (opaque).
    double? endOpacity,

    /// Scale at the start. `1` is the window's normal size.
    double? beginScale,

    /// Scale at the end. `1` is the window's normal size.
    double? endScale,

    /// Origin the scale animation grows from.
    Alignment? scaleAlignment,

    /// Whether position and size are interpolated.
    bool? animateRect,
  }) {
    return WindowTransitionStyle(
      duration: duration ?? this.duration,
      curve: curve ?? this.curve,
      beginOpacity: beginOpacity ?? this.beginOpacity,
      endOpacity: endOpacity ?? this.endOpacity,
      beginScale: beginScale ?? this.beginScale,
      endScale: endScale ?? this.endScale,
      scaleAlignment: scaleAlignment ?? this.scaleAlignment,
      animateRect: animateRect ?? this.animateRect,
    );
  }
}

/// Per-action animations for open, close, minimize, restore, maximize,
/// and unmaximize.
///
/// Each action is an independent [WindowTransitionStyle]. Use [none] to
/// turn every animation off.
class DraggableWindowAnimations {
  /// Transition played when the window becomes visible.
  final WindowTransitionStyle open;

  /// Transition played when the window hides.
  final WindowTransitionStyle close;

  /// Transition played when the window collapses to its header.
  final WindowTransitionStyle minimize;

  /// Transition played when a minimized window expands again.
  final WindowTransitionStyle restore;

  /// Transition played when the window grows to its maximum size.
  final WindowTransitionStyle maximize;

  /// Transition played when the window leaves the maximized state.
  final WindowTransitionStyle unmaximize;

  /// Creates the set of per-action transitions.
  ///
  /// Each argument is independent, so one action can be replaced without
  /// changing the others.
  const DraggableWindowAnimations({
    this.open = const WindowTransitionStyle(
      duration: Duration(milliseconds: 180),
      beginOpacity: 0,
      endOpacity: 1,
      beginScale: 0.96,
      endScale: 1,
      animateRect: false,
    ),
    this.close = const WindowTransitionStyle(
      duration: Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      beginOpacity: 1,
      endOpacity: 0,
      beginScale: 1,
      endScale: 0.96,
      animateRect: false,
    ),
    this.minimize = const WindowTransitionStyle(
      duration: Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      scaleAlignment: Alignment.topCenter,
    ),
    this.restore = const WindowTransitionStyle(
      duration: Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      scaleAlignment: Alignment.topCenter,
    ),
    this.maximize = const WindowTransitionStyle(
      duration: Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    ),
    this.unmaximize = const WindowTransitionStyle(
      duration: Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    ),
  });

  /// Preset where every action finishes immediately.
  static const DraggableWindowAnimations none = DraggableWindowAnimations(
    open: WindowTransitionStyle.instant,
    close: WindowTransitionStyle.instant,
    minimize: WindowTransitionStyle.instant,
    restore: WindowTransitionStyle.instant,
    maximize: WindowTransitionStyle.instant,
    unmaximize: WindowTransitionStyle.instant,
  );

  /// Returns a copy with the given actions replaced.
  ///
  /// A null argument keeps the current transition.
  DraggableWindowAnimations copyWith({
    /// Transition played when the window becomes visible.
    WindowTransitionStyle? open,

    /// Transition played when the window hides.
    WindowTransitionStyle? close,

    /// Transition played when the window collapses to its header.
    WindowTransitionStyle? minimize,

    /// Transition played when a minimized window expands again.
    WindowTransitionStyle? restore,

    /// Transition played when the window grows to its maximum size.
    WindowTransitionStyle? maximize,

    /// Transition played when the window leaves the maximized state.
    WindowTransitionStyle? unmaximize,
  }) {
    return DraggableWindowAnimations(
      open: open ?? this.open,
      close: close ?? this.close,
      minimize: minimize ?? this.minimize,
      restore: restore ?? this.restore,
      maximize: maximize ?? this.maximize,
      unmaximize: unmaximize ?? this.unmaximize,
    );
  }
}

// ============================================================================
// CONFIGURATION
// ============================================================================

/// Appearance, size limits, header, and animations for a
/// [DraggableOverlayWindow].
///
/// Colors left null follow the current [Theme]. [defaultConfig] is the
/// standard look and [compactConfig] is a tighter preset. [copyWith] changes
/// individual fields.
class DraggableWindowConfig {
  /// Height of the window while it is minimized and [showHeader] is true.
  ///
  /// Only the header is visible at this height.
  final double minimizedHeight;

  /// Corner radius of the window, in logical pixels.
  final double borderRadius;

  /// Shadow elevation while the window is not focused.
  final double elevation;

  /// Shadow elevation while the window is focused.
  final double focusedElevation;

  /// Header background color.
  ///
  /// When null, a theme color is used and it shifts slightly while focused.
  final Color? headerBackgroundColor;

  /// Window background color.
  ///
  /// When null, [ThemeData.scaffoldBackgroundColor] is used.
  final Color? windowBackgroundColor;

  /// Border color while the window is not focused.
  ///
  /// When null, a light grey is used.
  final Color? borderColor;

  /// Border color while the window is focused.
  ///
  /// When null, [ColorScheme.primary] is used.
  final Color? focusedBorderColor;

  /// Whether the content scrolls when it is taller than the window.
  ///
  /// When true, the content is wrapped in a [SingleChildScrollView].
  final bool enableScrolling;

  /// Padding around [DraggableOverlayWindow.content].
  final EdgeInsets contentPadding;

  /// Whether the window can be resized by dragging its edges.
  ///
  /// [resizeWidth] and [resizeHeight] choose which axes actually move.
  final bool resizable;

  /// Whether dragging an edge can change the width.
  ///
  /// Has no effect when [resizable] is false.
  final bool resizeWidth;

  /// Whether dragging an edge can change the height.
  ///
  /// Has no effect when [resizable] is false.
  final bool resizeHeight;

  /// Thickness, in logical pixels, of the invisible drag strips on the
  /// edges and corners.
  final double resizeHandleSize;

  /// Smallest width the window can be resized to.
  final double minWidth;

  /// Smallest height the window can be resized to.
  ///
  /// While the header is visible, the window also cannot shrink below
  /// [minimizedHeight].
  final double minHeight;

  /// Largest width the window can be resized to.
  ///
  /// Null means the screen width is the only limit.
  final double? maxWidth;

  /// Largest height the window can be resized to.
  ///
  /// Null means the screen height is the only limit.
  final double? maxHeight;

  /// Width used when the controller does not already have a positive size.
  final double initialWidth;

  /// Height used when the controller does not already have a positive size.
  final double initialHeight;

  /// When set, the laid-out width comes from the screen width.
  ///
  /// Ignored while the window is maximized. The function receives the
  /// current screen width and returns the window width.
  final double Function(double screenWidth)? widthCalculator;

  /// When set, the laid-out height comes from the screen height.
  ///
  /// Ignored while the window is maximized. The function receives the
  /// current screen height and returns the window height.
  final double Function(double screenHeight)? heightCalculator;

  /// Icon of the button that minimizes the window.
  final IconData minimizeIcon;

  /// Icon of the button that restores a minimized window.
  final IconData maximizeIcon;

  /// Icon of the button that maximizes the window.
  final IconData windowMaximizeIcon;

  /// Icon of the button that leaves the maximized state.
  final IconData windowRestoreIcon;

  /// Icon of the button that hides the window.
  final IconData closeIcon;

  /// Icon shown at the start of the header as the drag affordance.
  final IconData dragHandleIcon;

  /// Creates a window configuration.
  ///
  /// Omitted colors follow the current [Theme]. See each field for what a
  /// value controls and which default applies.
  const DraggableWindowConfig({
    this.minimizedHeight = 48.0,
    this.borderRadius = 12.0,
    this.elevation = 8.0,
    this.focusedElevation = 16.0,
    this.headerBackgroundColor,
    this.windowBackgroundColor,
    this.borderColor,
    this.focusedBorderColor,
    this.enableScrolling = true,
    this.contentPadding = const EdgeInsets.only(bottom: 8),
    this.resizable = true,
    this.resizeWidth = true,
    this.resizeHeight = true,
    this.resizeHandleSize = 8.0,
    this.minWidth = 200.0,
    this.minHeight = 150.0,
    this.maxWidth,
    this.maxHeight,
    this.initialWidth = 400.0,
    this.initialHeight = 350.0,
    this.widthCalculator,
    this.heightCalculator,
    this.minimizeIcon = Icons.remove,
    this.maximizeIcon = Icons.open_in_full,
    this.windowMaximizeIcon = Icons.crop_square,
    this.windowRestoreIcon = Icons.filter_none,
    this.closeIcon = Icons.close,
    this.dragHandleIcon = Icons.drag_handle,
    this.borderWidth = 1.0,
    this.focusedBorderWidth,
    this.showFocusBorder = true,
    this.dividerHeight = 1.0,
    this.showDivider = true,
    this.showHeader = true,
    this.dividerColor,
    this.headerPadding,
    this.headerIconColor,
    this.headerButtonsColor,
    this.headerTextStyle,
    this.animations = const DraggableWindowAnimations(),
  });

  /// Border thickness while the window is not focused, in logical pixels.
  final double borderWidth;

  /// Border thickness while the window is focused, in logical pixels.
  ///
  /// When null, or when [showFocusBorder] is false, [borderWidth] is used.
  final double? focusedBorderWidth;

  /// Whether the focused window uses [focusedBorderColor] and
  /// [focusedBorderWidth].
  ///
  /// When false, the unfocused border color and [borderWidth] stay in place.
  final bool showFocusBorder;

  /// Thickness of the divider between the header and the content.
  final double dividerHeight;

  /// Whether the divider between the header and the content is drawn.
  ///
  /// Has no effect when [showHeader] is false.
  final bool showDivider;

  /// Whether the top bar is shown.
  ///
  /// The bar holds the title, the drag handle, and the minimize, maximize,
  /// and close buttons. When false, the window is only its content and the
  /// content itself can be dragged. Closing, minimizing, and restoring remain
  /// available on [DraggableWindowController].
  final bool showHeader;

  /// Whether a maximize button is meaningful for this configuration.
  ///
  /// True when [resizable] is true and at least one of [resizeWidth] or
  /// [resizeHeight] is true.
  bool get canMaximize => resizable && (resizeWidth || resizeHeight);

  /// Color of the divider between the header and the content.
  ///
  /// When null, a faded border color is used.
  final Color? dividerColor;

  /// Padding inside the header.
  ///
  /// When null, 12 logical pixels of horizontal padding are used.
  final EdgeInsets? headerPadding;

  /// Color of the drag handle and the optional header icon.
  ///
  /// When null, the icon uses the theme color, and [ColorScheme.primary]
  /// while the window is focused.
  final Color? headerIconColor;

  /// Color of the minimize, maximize, and restore buttons.
  ///
  /// When null, [headerIconColor] is used. The close button stays red.
  final Color? headerButtonsColor;

  /// Text style of the header title.
  ///
  /// When null, the theme's title style is used, and it becomes bolder
  /// while the window is focused.
  final TextStyle? headerTextStyle;

  /// Animations for open, close, minimize, restore, maximize, and unmaximize.
  final DraggableWindowAnimations animations;

  /// Standard configuration, equal to [DraggableWindowConfig.new] with no
  /// arguments.
  static const DraggableWindowConfig defaultConfig = DraggableWindowConfig();

  /// Tighter configuration for smaller screens.
  ///
  /// Uses a shorter header, smaller corners, less elevation, and smaller
  /// minimum and initial sizes than [defaultConfig].
  static const DraggableWindowConfig compactConfig = DraggableWindowConfig(
    minimizedHeight: 40.0,
    borderRadius: 8.0,
    elevation: 6.0,
    focusedElevation: 12.0,
    contentPadding: EdgeInsets.only(bottom: 4),
    minWidth: 150.0,
    minHeight: 100.0,
    initialWidth: 300.0,
    initialHeight: 250.0,
  );

  /// Returns a copy with the given fields replaced.
  ///
  /// A null argument keeps the current value, so this cannot clear a color,
  /// calculator, or text style back to null. Each parameter matches the field
  /// of the same name.
  DraggableWindowConfig copyWith({
    /// Height of the minimized window when the header is visible.
    double? minimizedHeight,

    /// Corner radius of the window, in logical pixels.
    double? borderRadius,

    /// Shadow elevation while the window is not focused.
    double? elevation,

    /// Shadow elevation while the window is focused.
    double? focusedElevation,

    /// Header background color. Null keeps the current color.
    Color? headerBackgroundColor,

    /// Window background color. Null keeps the current color.
    Color? windowBackgroundColor,

    /// Border color while the window is not focused. Null keeps the current color.
    Color? borderColor,

    /// Border color while the window is focused. Null keeps the current color.
    Color? focusedBorderColor,

    /// Whether the content scrolls when it is taller than the window.
    bool? enableScrolling,

    /// Padding around the window content.
    EdgeInsets? contentPadding,

    /// Whether the window can be resized by dragging its edges.
    bool? resizable,

    /// Whether dragging an edge can change the width.
    bool? resizeWidth,

    /// Whether dragging an edge can change the height.
    bool? resizeHeight,

    /// Thickness of the invisible drag strips on the edges and corners.
    double? resizeHandleSize,

    /// Smallest width the window can be resized to.
    double? minWidth,

    /// Smallest height the window can be resized to.
    double? minHeight,

    /// Largest width the window can be resized to. Null keeps the current limit.
    double? maxWidth,

    /// Largest height the window can be resized to. Null keeps the current limit.
    double? maxHeight,

    /// Width used when the controller does not already have a positive size.
    double? initialWidth,

    /// Height used when the controller does not already have a positive size.
    double? initialHeight,

    /// Function that sets the width from the screen width. Null keeps the current function.
    double Function(double screenWidth)? widthCalculator,

    /// Function that sets the height from the screen height. Null keeps the current function.
    double Function(double screenHeight)? heightCalculator,

    /// Icon of the button that minimizes the window.
    IconData? minimizeIcon,

    /// Icon of the button that restores a minimized window.
    IconData? maximizeIcon,

    /// Icon of the button that maximizes the window.
    IconData? windowMaximizeIcon,

    /// Icon of the button that leaves the maximized state.
    IconData? windowRestoreIcon,

    /// Icon of the button that hides the window.
    IconData? closeIcon,

    /// Icon shown at the start of the header as the drag affordance.
    IconData? dragHandleIcon,

    /// Border thickness while the window is not focused.
    double? borderWidth,

    /// Border thickness while focused. Null keeps the current value.
    double? focusedBorderWidth,

    /// Whether the focused window uses the focus border color and width.
    bool? showFocusBorder,

    /// Thickness of the divider between the header and the content.
    double? dividerHeight,

    /// Whether the divider between the header and the content is drawn.
    bool? showDivider,

    /// Whether the top bar is shown.
    bool? showHeader,

    /// Color of the divider between the header and the content.
    Color? dividerColor,

    /// Padding inside the header. Null keeps the current padding.
    EdgeInsets? headerPadding,

    /// Color of the drag handle and the optional header icon.
    Color? headerIconColor,

    /// Color of the minimize, maximize, and restore buttons.
    Color? headerButtonsColor,

    /// Text style of the header title. Null keeps the current style.
    TextStyle? headerTextStyle,

    /// Animations for open, close, minimize, restore, maximize, and unmaximize.
    DraggableWindowAnimations? animations,
  }) {
    return DraggableWindowConfig(
      minimizedHeight: minimizedHeight ?? this.minimizedHeight,
      borderRadius: borderRadius ?? this.borderRadius,
      elevation: elevation ?? this.elevation,
      focusedElevation: focusedElevation ?? this.focusedElevation,
      headerBackgroundColor:
          headerBackgroundColor ?? this.headerBackgroundColor,
      windowBackgroundColor:
          windowBackgroundColor ?? this.windowBackgroundColor,
      borderColor: borderColor ?? this.borderColor,
      focusedBorderColor: focusedBorderColor ?? this.focusedBorderColor,
      enableScrolling: enableScrolling ?? this.enableScrolling,
      contentPadding: contentPadding ?? this.contentPadding,
      resizable: resizable ?? this.resizable,
      resizeWidth: resizeWidth ?? this.resizeWidth,
      resizeHeight: resizeHeight ?? this.resizeHeight,
      resizeHandleSize: resizeHandleSize ?? this.resizeHandleSize,
      minWidth: minWidth ?? this.minWidth,
      minHeight: minHeight ?? this.minHeight,
      maxWidth: maxWidth ?? this.maxWidth,
      maxHeight: maxHeight ?? this.maxHeight,
      initialWidth: initialWidth ?? this.initialWidth,
      initialHeight: initialHeight ?? this.initialHeight,
      widthCalculator: widthCalculator ?? this.widthCalculator,
      heightCalculator: heightCalculator ?? this.heightCalculator,
      minimizeIcon: minimizeIcon ?? this.minimizeIcon,
      maximizeIcon: maximizeIcon ?? this.maximizeIcon,
      windowMaximizeIcon: windowMaximizeIcon ?? this.windowMaximizeIcon,
      windowRestoreIcon: windowRestoreIcon ?? this.windowRestoreIcon,
      closeIcon: closeIcon ?? this.closeIcon,
      dragHandleIcon: dragHandleIcon ?? this.dragHandleIcon,
      borderWidth: borderWidth ?? this.borderWidth,
      focusedBorderWidth: focusedBorderWidth ?? this.focusedBorderWidth,
      showFocusBorder: showFocusBorder ?? this.showFocusBorder,
      dividerHeight: dividerHeight ?? this.dividerHeight,
      showDivider: showDivider ?? this.showDivider,
      showHeader: showHeader ?? this.showHeader,
      dividerColor: dividerColor ?? this.dividerColor,
      headerPadding: headerPadding ?? this.headerPadding,
      headerIconColor: headerIconColor ?? this.headerIconColor,
      headerButtonsColor: headerButtonsColor ?? this.headerButtonsColor,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
      animations: animations ?? this.animations,
    );
  }
}

// ============================================================================
// CONTROLLER
// ============================================================================

/// Programmatic control for one [DraggableOverlayWindow].
///
/// Call [show], [hide], [minimize], [restore], [maximize], and [unmaximize]
/// from application code. The widget listens and animates the change.
///
/// Pass the same [tag] to [DraggableWindowController.new] to reuse one
/// controller. [dispose] removes that tagged instance.
class DraggableWindowController extends ChangeNotifier {
  static final Map<String, DraggableWindowController> _instances = {};

  bool _isVisible = false;
  bool _isMinimized = false;
  bool _isMaximized = false;
  Offset? _restorePosition;
  Size? _restoreSize;
  Offset _position = const Offset(80, 100);
  Size _size;
  final String _windowId;
  final String? _tag;

  /// Creates a controller, or returns the one already stored for [tag].
  ///
  /// [initialSize] and [initialPosition] apply only when this call creates
  /// a new controller. If [tag] matches an existing controller, that instance
  /// is returned and the other arguments are ignored.
  factory DraggableWindowController({
    /// Size stored when this call creates a new controller.
    Size initialSize = const Size(400, 350),

    /// Top-left position stored when this call creates a new controller.
    Offset initialPosition = const Offset(80, 100),

    /// Optional identity that makes this controller a singleton.
    ///
    /// A later call with the same tag returns the existing controller.
    String? tag,
  }) {
    if (tag != null && _instances.containsKey(tag)) {
      return _instances[tag]!;
    }

    final controller = DraggableWindowController._internal(
      initialSize: initialSize,
      initialPosition: initialPosition,
      tag: tag,
    );

    if (tag != null) {
      _instances[tag] = controller;
    }

    return controller;
  }

  DraggableWindowController._internal({
    Size initialSize = const Size(400, 350),
    Offset initialPosition = const Offset(80, 100),
    String? tag,
  })  : _size = initialSize,
        _position = initialPosition,
        _windowId = WindowManager().generateId(),
        _tag = tag;

  /// Unique id of this window, assigned when the controller is created.
  String get windowId => _windowId;

  /// Whether the window is shown.
  ///
  /// False until [show] is called, and false again after [hide].
  bool get isVisible => _isVisible;

  /// Whether the window is collapsed to its header.
  bool get isMinimized => _isMinimized;

  /// Whether the window is expanded to its maximum size.
  bool get isMaximized => _isMaximized;

  /// Current top-left position of the window.
  Offset get position => _position;

  /// Current width and height of the window.
  ///
  /// While minimized, the painted height is
  /// [DraggableWindowConfig.minimizedHeight] and this size is the restored
  /// size.
  Size get size => _size;

  /// Whether this window is the focused one, painted above the others.
  bool get isFocused => WindowManager().isOnTop(_windowId);

  /// Shows the window, expands it if it was minimized, and focuses it.
  ///
  /// Does nothing when the window is already visible.
  void show() {
    if (!_isVisible) {
      _isVisible = true;
      _isMinimized = false;
      WindowManager().registerWindow(_windowId, tag: _tag);
      WindowManager().bringToFront(_windowId);
      notifyListeners();
    }
  }

  /// Hides the window and removes it from the stacking order.
  ///
  /// Does nothing when the window is already hidden. Minimized and maximized
  /// flags are left as they are.
  void hide() {
    if (_isVisible) {
      _isVisible = false;
      WindowManager().unregisterWindow(_windowId);
      notifyListeners();
    }
  }

  /// Hides the window when it is visible, or shows it when it is hidden.
  void toggle() {
    if (_isVisible) {
      hide();
    } else {
      show();
    }
  }

  /// Collapses a visible window to its header.
  ///
  /// Does nothing when the window is hidden or already minimized. This does
  /// not call [DraggableOverlayWindow.onMinimized]; that callback belongs to
  /// the header buttons.
  void minimize() {
    if (_isVisible && !_isMinimized) {
      _isMinimized = true;
      notifyListeners();
    }
  }

  /// Expands a minimized window back to [size].
  ///
  /// Does nothing when the window is hidden or not minimized. This does not
  /// leave the maximized state, and it does not call
  /// [DraggableOverlayWindow.onRestored].
  void restore() {
    if (_isVisible && _isMinimized) {
      _isMinimized = false;
      notifyListeners();
    }
  }

  /// Expands the window to the maximum size on each resizable axis.
  ///
  /// Also expands the window when it is minimized. Does nothing when the
  /// window is hidden or already maximized.
  void maximize() {
    if (!_isVisible || _isMaximized) return;
    _isMinimized = false;
    _isMaximized = true;
    notifyListeners();
  }

  /// Leaves the maximized state.
  ///
  /// The widget restores the size from before [maximize]. If that size is
  /// still flush with the maximum, it shrinks slightly so a resize edge
  /// remains. Does nothing when the window is not maximized.
  void unmaximize() {
    if (!_isMaximized) return;
    _isMaximized = false;
    notifyListeners();
  }

  /// Maximizes the window, or leaves the maximized state if it already is.
  void toggleMaximize() {
    if (_isMaximized) {
      unmaximize();
    } else {
      maximize();
    }
  }

  void _rememberRestore(Offset position, Size size) {
    _restorePosition ??= position;
    _restoreSize ??= size;
  }

  void _clearRestore() {
    _restorePosition = null;
    _restoreSize = null;
  }

  /// Minimizes a visible window, or restores it when it is already minimized.
  void toggleMinimize() {
    if (_isVisible) {
      _isMinimized = !_isMinimized;
      notifyListeners();
    }
  }

  /// Focuses this window and paints it above the others.
  void bringToFront() {
    WindowManager().bringToFront(_windowId);
  }

  /// Moves the window to [newPosition] and notifies listeners.
  ///
  /// Does nothing when [newPosition] is already the current [position].
  void setPosition(Offset newPosition) {
    if (_position != newPosition) {
      _position = newPosition;
      notifyListeners();
    }
  }

  /// Resizes the window to [newSize] and notifies listeners.
  ///
  /// Does nothing when [newSize] is already the current [size].
  void setSize(Size newSize) {
    if (_size != newSize) {
      _size = newSize;
      notifyListeners();
    }
  }

  /// Sets [position] and [size] without notifying listeners.
  ///
  /// Used while the window is being created, before the first frame. A null
  /// argument leaves that value unchanged.
  void setInitialState({
    /// Top-left position to store. Null leaves [position] unchanged.
    Offset? position,

    /// Size to store. Null leaves [size] unchanged.
    Size? size,
  }) {
    if (position != null) _position = position;
    if (size != null) _size = size;
  }

  /// Unregisters the window, drops a tagged instance, and releases listeners.
  @override
  void dispose() {
    WindowManager().unregisterWindow(_windowId);
    if (_tag != null) {
      _instances.remove(_tag);
    }
    super.dispose();
  }
}

// ============================================================================
// PRIVATE TYPES
// ============================================================================

/// Edge or corner being dragged while the window is resized.
enum _ResizeDirection {
  topLeft,
  top,
  topRight,
  left,
  right,
  bottomLeft,
  bottom,
  bottomRight,
}

// ============================================================================
// MAIN WIDGET
// ============================================================================

/// A floating window that can be dragged, resized, minimized, and maximized.
///
/// Place it in an [OverlayWindowStack] and drive it with [controller].
/// [content] stays mounted while the window is minimized, so its state is
/// kept. [config] controls appearance, limits, the header, and animations.
///
/// [key] is required. The stack reorders windows by focus, and the key keeps
/// each window's state.
class DraggableOverlayWindow extends StatefulWidget {
  /// Controller that shows, hides, moves, and resizes this window.
  final DraggableWindowController controller;

  /// Title drawn in the header.
  ///
  /// Nothing is drawn for the title when this is null, or when
  /// [DraggableWindowConfig.showHeader] is false.
  final String? title;

  /// Icon drawn in the header, before [title].
  ///
  /// Nothing is drawn when this is null, or when the header is hidden.
  final IconData? icon;

  /// Body of the window.
  ///
  /// Stays in the tree while the window is minimized.
  final Widget content;

  /// Appearance, size limits, header, and animations.
  final DraggableWindowConfig config;

  /// Called when the user focuses this window.
  ///
  /// Fired on tap, when a drag starts, and when a resize starts.
  final VoidCallback? onFocus;

  /// Called after the close animation finishes and the window is hidden.
  final VoidCallback? onClose;

  /// Called when the header minimizes the window.
  ///
  /// [DraggableWindowController.minimize] does not call this.
  final VoidCallback? onMinimized;

  /// Called when the header restores the window from the minimized state.
  ///
  /// [DraggableWindowController.restore] does not call this. Leaving the
  /// maximized state does not call this either.
  final VoidCallback? onRestored;

  /// Called with the new top-left offset after a drag, resize, or animation
  /// commits a new position.
  final ValueChanged<Offset>? onPositionChanged;

  /// Called with the new size after a resize or animation commits a new size.
  final ValueChanged<Size>? onSizeChanged;

  /// Creates an overlay window controlled by [controller].
  ///
  /// [key] is required so [OverlayWindowStack] can reorder windows without
  /// disposing [content]. [config] defaults to [DraggableWindowConfig.new].
  const DraggableOverlayWindow({
    required Key key,
    required this.controller,
    required this.content,
    this.title,
    this.icon,
    this.config = const DraggableWindowConfig(),
    this.onFocus,
    this.onClose,
    this.onMinimized,
    this.onRestored,
    this.onPositionChanged,
    this.onSizeChanged,
  }) : super(key: key);

  @override
  State<DraggableOverlayWindow> createState() => _DraggableOverlayWindowState();
}

enum _WindowMotion { open, close, minimize, restore, maximize, unmaximize }

class _DraggableOverlayWindowState extends State<DraggableOverlayWindow>
    with SingleTickerProviderStateMixin {
  late Offset _currentPosition;
  late Size _currentSize;
  late final AnimationController _motion;
  final WindowManager _windowManager = WindowManager();
  bool _syncingMaximize = false;
  bool _listenToMotion = false;
  bool _interacting = false;
  bool _closing = false;
  bool _wasVisible = false;
  bool _wasMinimized = false;
  bool _wasMaximized = false;
  bool _wasFocused = false;
  Rect? _fromRect;
  Rect? _toRect;
  WindowTransitionStyle? _activeStyle;
  VoidCallback? _whenMotionEnds;
  double _restOpacity = 1;
  double _restScale = 1;

  /// Minimum gap, on each side, when leaving a window that is flush with
  /// the maximum size.
  static const double _restoreInset = 24;

  DraggableWindowController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _initializeSize();
    _currentPosition = _controller.position;
    _wasVisible = _controller.isVisible;
    _wasMinimized = _controller.isMinimized;
    _wasMaximized = _controller.isMaximized;
    _wasFocused = _windowManager.isOnTop(_controller.windowId);
    _motion = AnimationController(vsync: this);
    _motion.addListener(() {
      if (_listenToMotion && mounted) setState(() {});
    });
    _motion.addStatusListener((status) {
      if (status != AnimationStatus.completed || _activeStyle == null) return;
      _restOpacity = _activeStyle!.endOpacity;
      _restScale = _activeStyle!.endScale;
      final done = _whenMotionEnds;
      _whenMotionEnds = null;
      _activeStyle = null;
      done?.call();
    });
    _controller.addListener(_onControllerChanged);
    _windowManager.addListener(_onWindowManagerChanged);

    if (_controller.isVisible) {
      _windowManager.registerWindow(_controller.windowId,
          tag: _controller._tag);
      final open = widget.config.animations.open;
      if (open.duration > Duration.zero) {
        final rect = _rectOf(_currentPosition, _currentSize);
        _play(open, rect, rect);
      }
    }
    _listenToMotion = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMaximize();
  }

  void _initializeSize() {
    // Use the controller size when it is already set; otherwise use the config.
    if (_controller.size.width > 0 && _controller.size.height > 0) {
      _currentSize = _controller.size;
    } else {
      _currentSize = Size(
        widget.config.initialWidth,
        widget.config.initialHeight,
      );
      _controller.setInitialState(size: _currentSize);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _windowManager.removeListener(_onWindowManagerChanged);
    _motion.dispose();
    super.dispose();
  }

  Rect _rectOf(Offset position, Size size) {
    return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  }

  Rect _onScreenRect() {
    if (_motion.isAnimating && _fromRect != null && _toRect != null) {
      return _paintedRect();
    }
    final height = (_wasMinimized && widget.config.showHeader)
        ? widget.config.minimizedHeight
        : _currentSize.height;
    return _rectOf(_currentPosition, Size(_currentSize.width, height));
  }

  Rect _targetRect() {
    final height = (_controller.isMinimized && widget.config.showHeader)
        ? widget.config.minimizedHeight
        : _currentSize.height;
    return _rectOf(_currentPosition, Size(_currentSize.width, height));
  }

  Rect _paintedRect() {
    final style = _activeStyle;
    final from = _fromRect;
    final to = _toRect;
    if (style == null || from == null || to == null || !_motion.isAnimating) {
      return _targetRect();
    }
    final t = style.curve.transform(_motion.value);
    if (!style.animateRect) return to;
    return Rect.lerp(from, to, t) ?? to;
  }

  double _paintedOpacity() {
    final style = _activeStyle;
    if (style == null || !_motion.isAnimating) return _restOpacity;
    final t = style.curve.transform(_motion.value);
    return style.beginOpacity + (style.endOpacity - style.beginOpacity) * t;
  }

  double _paintedScale() {
    final style = _activeStyle;
    if (style == null || !_motion.isAnimating) return _restScale;
    final t = style.curve.transform(_motion.value);
    return style.beginScale + (style.endScale - style.beginScale) * t;
  }

  Alignment get _scaleAlignment =>
      _activeStyle?.scaleAlignment ?? Alignment.center;

  WindowTransitionStyle _styleFor(_WindowMotion motion) {
    final animations = widget.config.animations;
    final style = switch (motion) {
      _WindowMotion.open => animations.open,
      _WindowMotion.close => animations.close,
      _WindowMotion.minimize => animations.minimize,
      _WindowMotion.restore => animations.restore,
      _WindowMotion.maximize => animations.maximize,
      _WindowMotion.unmaximize => animations.unmaximize,
    };
    final headerless = !widget.config.showHeader;
    if (motion == _WindowMotion.minimize &&
        headerless &&
        style.beginOpacity == style.endOpacity &&
        style.beginScale == style.endScale) {
      return style.copyWith(endOpacity: 0, endScale: 0.92);
    }
    if (motion == _WindowMotion.restore &&
        headerless &&
        style.beginOpacity == style.endOpacity &&
        style.beginScale == style.endScale) {
      return style.copyWith(
        beginOpacity: 0,
        beginScale: 0.92,
        endOpacity: 1,
        endScale: 1,
      );
    }
    return style;
  }

  void _play(
    WindowTransitionStyle style,
    Rect from,
    Rect to, {
    VoidCallback? onEnd,
  }) {
    _whenMotionEnds = null;
    _motion.stop();
    final effective = style;
    if (effective.duration == Duration.zero) {
      _activeStyle = null;
      _restOpacity = effective.endOpacity;
      _restScale = effective.endScale;
      _fromRect = to;
      _toRect = to;
      onEnd?.call();
      return;
    }
    _activeStyle = effective;
    _fromRect = effective.animateRect ? from : to;
    _toRect = to;
    _whenMotionEnds = onEnd;
    _motion.duration = effective.duration;
    _motion.forward(from: 0);
  }

  void _finishClose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _closing = false;
      widget.onClose?.call();
      if (mounted) setState(() {});
    });
  }

  void _onControllerChanged() {
    if (!mounted || _syncingMaximize) return;
    final from = _onScreenRect();
    final wasVisible = _wasVisible;
    final wasMinimized = _wasMinimized;
    final wasMaximized = _wasMaximized;
    _syncMaximize();
    if (!mounted) return;

    _currentPosition = _controller.position;
    _currentSize = _controller.size;
    final to = _targetRect();

    _WindowMotion? motion;
    if (_controller.isVisible && !wasVisible) {
      motion = _WindowMotion.open;
      _closing = false;
    } else if (!_controller.isVisible && wasVisible) {
      motion = _WindowMotion.close;
      _closing = true;
    } else if (_controller.isMaximized != wasMaximized) {
      motion = _controller.isMaximized
          ? _WindowMotion.maximize
          : _WindowMotion.unmaximize;
    } else if (_controller.isMinimized != wasMinimized) {
      motion = _controller.isMinimized
          ? _WindowMotion.minimize
          : _WindowMotion.restore;
    }

    _wasVisible = _controller.isVisible;
    _wasMinimized = _controller.isMinimized;
    _wasMaximized = _controller.isMaximized;

    if ((_interacting && motion != _WindowMotion.close) || motion == null) {
      _whenMotionEnds = null;
      _motion.stop();
      _activeStyle = null;
      _restOpacity = 1;
      _restScale = 1;
      setState(() {});
      return;
    }

    _play(
      _styleFor(motion),
      from,
      motion == _WindowMotion.close ? from : to,
      onEnd: motion == _WindowMotion.close ? _finishClose : null,
    );
    setState(() {});
  }

  void _syncMaximize() {
    if (!mounted || _syncingMaximize) return;
    final config = widget.config;
    if (!config.canMaximize) {
      if (_controller.isMaximized) {
        _syncingMaximize = true;
        _controller.unmaximize();
        _syncingMaximize = false;
      }
      return;
    }

    final screen = MediaQuery.sizeOf(context);
    if (_controller.isMaximized) {
      _controller._rememberRestore(_currentPosition, _currentSize);
      final frame = _maximizedFrame(screen);
      _applyFrame(frame.position, frame.size);
      return;
    }

    final savedPosition = _controller._restorePosition;
    final savedSize = _controller._restoreSize;
    if (savedPosition == null || savedSize == null) return;
    _controller._clearRestore();
    final frame = _restoredFrame(screen, savedPosition, savedSize);
    _applyFrame(frame.position, frame.size);
  }

  ({Offset position, Size size}) _maximizedFrame(Size screen) {
    final config = widget.config;
    var width = _currentSize.width;
    var height = _currentSize.height;
    var x = _currentPosition.dx;
    var y = _currentPosition.dy;

    if (config.resizeWidth) {
      final ceiling = _axisCeiling(screen.width, config.maxWidth);
      width = ceiling.clamp(config.minWidth, double.infinity);
      x = 0;
    }
    if (config.resizeHeight) {
      final ceiling = _axisCeiling(screen.height, config.maxHeight);
      height = ceiling.clamp(config.minHeight, double.infinity);
      y = 0;
    }

    return (position: Offset(x, y), size: Size(width, height));
  }

  ({Offset position, Size size}) _restoredFrame(
    Size screen,
    Offset savedPosition,
    Size savedSize,
  ) {
    final config = widget.config;
    var width = savedSize.width;
    var height = savedSize.height;
    var x = savedPosition.dx;
    var y = savedPosition.dy;

    if (config.resizeWidth) {
      final ceiling = _axisCeiling(screen.width, config.maxWidth);
      final adjusted = _shrinkFromEdge(
        value: width,
        origin: x,
        ceiling: ceiling,
        screenExtent: screen.width,
        minimum: config.minWidth,
      );
      width = adjusted.value;
      x = adjusted.origin;
    }
    if (config.resizeHeight) {
      final ceiling = _axisCeiling(screen.height, config.maxHeight);
      final adjusted = _shrinkFromEdge(
        value: height,
        origin: y,
        ceiling: ceiling,
        screenExtent: screen.height,
        minimum: config.minHeight,
      );
      height = adjusted.value;
      y = adjusted.origin;
    }

    return (position: Offset(x, y), size: Size(width, height));
  }

  double _axisCeiling(double screenExtent, double? configuredMax) {
    final limit = configuredMax ?? screenExtent;
    return limit < screenExtent ? limit : screenExtent;
  }

  ({double value, double origin}) _shrinkFromEdge({
    required double value,
    required double origin,
    required double ceiling,
    required double screenExtent,
    required double minimum,
  }) {
    var next = value;
    var nextOrigin = origin;
    if (ceiling - value < _restoreInset && value > minimum) {
      final shrunk =
          (value - _restoreInset * 2).clamp(minimum, value).toDouble();
      if (shrunk < value) {
        final lost = value - shrunk;
        next = shrunk;
        nextOrigin = origin + lost / 2;
      }
    }
    final room = screenExtent - next;
    final maxOrigin = room < 0 ? 0.0 : room;
    nextOrigin = nextOrigin.clamp(0.0, maxOrigin).toDouble();
    return (value: next, origin: nextOrigin);
  }

  void _applyFrame(Offset position, Size size) {
    final positionChanged = _currentPosition != position;
    final sizeChanged = _currentSize != size;
    if (!positionChanged && !sizeChanged) return;

    _currentPosition = position;
    _currentSize = size;
    _syncingMaximize = true;
    _controller.setPosition(position);
    _controller.setSize(size);
    _syncingMaximize = false;
    if (positionChanged) widget.onPositionChanged?.call(position);
    if (sizeChanged) widget.onSizeChanged?.call(size);
  }

  void _onWindowManagerChanged() {
    final isFocused = _windowManager.isOnTop(_controller.windowId);
    if (mounted && isFocused != _wasFocused) {
      _wasFocused = isFocused;
      setState(() {});
    }
  }

  double _calculateWidth(BuildContext context) {
    if (_controller.isMaximized) return _currentSize.width;
    if (widget.config.widthCalculator != null) {
      final screenWidth = MediaQuery.of(context).size.width;
      return widget.config.widthCalculator!(screenWidth);
    }
    return _currentSize.width;
  }

  double _calculateHeight(BuildContext context) {
    if (_controller.isMaximized) return _currentSize.height;
    if (widget.config.heightCalculator != null) {
      final screenHeight = MediaQuery.of(context).size.height;
      return widget.config.heightCalculator!(screenHeight);
    }
    return _currentSize.height;
  }

  void _handleTap() {
    _controller.bringToFront();
    widget.onFocus?.call();
  }

  void _cancelMotionForGesture() {
    if (_closing) return;
    _interacting = true;
    _whenMotionEnds = null;
    _motion.stop();
    _activeStyle = null;
    _restOpacity = 1;
    _restScale = 1;
  }

  void _handleDragStart(DragStartDetails details) {
    if (_closing) return;
    _cancelMotionForGesture();
    _controller.bringToFront();
    widget.onFocus?.call();
  }

  void _handleDrag(DragUpdateDetails details) {
    if (_closing || _controller.isMaximized) return;
    final screenSize = MediaQuery.of(context).size;
    final width = _calculateWidth(context);
    // Use minimizedHeight while the window is minimized.
    final height = _controller.isMinimized
        ? widget.config.minimizedHeight
        : _calculateHeight(context);

    final newPosition = Offset(
      (_currentPosition.dx + details.delta.dx).clamp(
        0.0,
        screenSize.width - width,
      ),
      (_currentPosition.dy + details.delta.dy).clamp(
        0.0,
        screenSize.height - height,
      ),
    );

    setState(() {
      _currentPosition = newPosition;
    });

    _controller.setPosition(newPosition);
    widget.onPositionChanged?.call(newPosition);
  }

  void _handleResize(_ResizeDirection direction, DragUpdateDetails details) {
    if (_closing || _controller.isMaximized) return;
    final screenSize = MediaQuery.of(context).size;
    final config = widget.config;
    final allowWidth = config.resizeWidth;
    final allowHeight = config.resizeHeight;
    if (!allowWidth && !allowHeight) return;

    final dx = details.delta.dx;
    final dy = details.delta.dy;

    // Current position and size.
    double left = _currentPosition.dx;
    double top = _currentPosition.dy;
    double width = _currentSize.width;
    double height = _currentSize.height;

    if (allowWidth) {
      switch (direction) {
        case _ResizeDirection.left:
        case _ResizeDirection.topLeft:
        case _ResizeDirection.bottomLeft:
          // Dragging the left edge moves the left edge.
          left += dx;
          width -= dx;
          break;
        case _ResizeDirection.right:
        case _ResizeDirection.topRight:
        case _ResizeDirection.bottomRight:
          width += dx;
          break;
        default:
          break;
      }
    }

    if (allowHeight) {
      switch (direction) {
        case _ResizeDirection.top:
        case _ResizeDirection.topLeft:
        case _ResizeDirection.topRight:
          // Dragging the top edge moves the top edge.
          top += dy;
          height -= dy;
          break;
        case _ResizeDirection.bottom:
        case _ResizeDirection.bottomLeft:
        case _ResizeDirection.bottomRight:
          height += dy;
          break;
        default:
          break;
      }
    }

    // Apply the minimum size.
    if (allowWidth && width < config.minWidth) {
      if (direction == _ResizeDirection.left ||
          direction == _ResizeDirection.topLeft ||
          direction == _ResizeDirection.bottomLeft) {
        // When the left edge hits the minimum width, keep that width
        // by adjusting the left position.
        left = _currentPosition.dx + (_currentSize.width - config.minWidth);
      }
      width = config.minWidth;
    }

    if (allowHeight && height < config.minHeight) {
      if (direction == _ResizeDirection.top ||
          direction == _ResizeDirection.topLeft ||
          direction == _ResizeDirection.topRight) {
        // When the top edge hits the minimum height, keep that height
        // by adjusting the top position.
        top = _currentPosition.dy + (_currentSize.height - config.minHeight);
      }
      height = config.minHeight;
    }

    // Apply the maximum size.
    final maxW = config.maxWidth ?? screenSize.width;
    final maxH = config.maxHeight ?? screenSize.height;

    if (allowWidth && width > maxW) {
      if (direction == _ResizeDirection.left ||
          direction == _ResizeDirection.topLeft ||
          direction == _ResizeDirection.bottomLeft) {
        left = _currentPosition.dx + (_currentSize.width - maxW);
      }
      width = maxW;
    }

    if (allowHeight && height > maxH) {
      if (direction == _ResizeDirection.top ||
          direction == _ResizeDirection.topLeft ||
          direction == _ResizeDirection.topRight) {
        top = _currentPosition.dy + (_currentSize.height - maxH);
      }
      height = maxH;
    }

    // Keep the window inside the screen.
    if (allowWidth && left < 0) {
      width += left;
      left = 0;
    }
    if (allowHeight && top < 0) {
      height += top;
      top = 0;
    }

    // Keep the right edge inside the screen.
    if (allowWidth && left + width > screenSize.width) {
      if (direction == _ResizeDirection.left ||
          direction == _ResizeDirection.topLeft ||
          direction == _ResizeDirection.bottomLeft) {
        left = screenSize.width - width;
        if (left < 0) {
          left = 0;
          width = screenSize.width;
        }
      } else {
        width = screenSize.width - left;
      }
    }

    // Keep the bottom edge inside the screen.
    if (allowHeight && top + height > screenSize.height) {
      if (direction == _ResizeDirection.top ||
          direction == _ResizeDirection.topLeft ||
          direction == _ResizeDirection.topRight) {
        top = screenSize.height - height;
        if (top < 0) {
          top = 0;
          height = screenSize.height;
        }
      } else {
        height = screenSize.height - top;
      }
    }

    // A disabled axis stays exactly as it was.
    if (!allowWidth) {
      left = _currentPosition.dx;
      width = _currentSize.width;
    }
    if (!allowHeight) {
      top = _currentPosition.dy;
      height = _currentSize.height;
    }

    // Update state.
    final newPosition = Offset(left, top);
    final newSize = Size(width, height);

    setState(() {
      _currentPosition = newPosition;
      _currentSize = newSize;
    });

    _controller.setPosition(newPosition);
    _controller.setSize(newSize);
    widget.onPositionChanged?.call(newPosition);
    widget.onSizeChanged?.call(newSize);
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isVisible && !_closing) {
      return const SizedBox.shrink();
    }

    final isMinimized = _controller.isMinimized;
    final animating = _motion.isAnimating;
    // While the height animates, the content stays visible and is clipped.
    final showMinimizedChrome = isMinimized && !animating;
    final isFocused = _windowManager.isOnTop(_controller.windowId);
    final config = widget.config;
    // With a header, the window cannot shrink below the header.
    // Without a header, the floor is only minHeight.
    var heightFloor = config.minHeight;
    if (config.showHeader) {
      final chrome = config.minimizedHeight +
          (config.showDivider ? config.dividerHeight : 0);
      if (chrome > heightFloor) heightFloor = chrome;
    }
    // Real content height. Minimizing shrinks the window, but the body keeps
    // this size so its State is not recreated.
    final fullHeight =
        _calculateHeight(context).clamp(heightFloor, double.infinity);
    final paint = animating ? _paintedRect() : null;
    final width = paint?.width ??
        _calculateWidth(context).clamp(config.minWidth, double.infinity);
    final height = paint?.height ??
        ((showMinimizedChrome && config.showHeader)
            ? config.minimizedHeight
            : fullHeight);
    final offset = paint?.topLeft ?? _currentPosition;

    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(config.borderRadius);

    final backgroundColor =
        config.windowBackgroundColor ?? theme.scaffoldBackgroundColor;
    final borderColor = isFocused
        ? (config.focusedBorderColor ?? theme.colorScheme.primary)
        : (config.borderColor ?? Colors.grey.shade300);
    final elevation = isFocused ? config.focusedElevation : config.elevation;

    final headerHeight = config.showHeader ? config.minimizedHeight : 0.0;
    final dividerHeight =
        (config.showHeader && config.showDivider) ? config.dividerHeight : 0.0;
    final bodyHeight =
        (fullHeight - headerHeight - dividerHeight).clamp(0.0, double.infinity);
    final bodyRadius = config.showHeader
        ? BorderRadius.vertical(
            bottom: Radius.circular(config.borderRadius),
          )
        : BorderRadius.circular(config.borderRadius);

    // Align + Transform avoids ParentData errors inside the Stack
    // and keeps the origin at (0, 0) so the offset is applied correctly.
    // Offstage at the root only hides a headerless window: the child stays mounted.
    final opacity = _paintedOpacity().clamp(0.0, 1.0);
    final scale = _paintedScale() < 0 ? 0.0 : _paintedScale();
    return Offstage(
      offstage: showMinimizedChrome && !config.showHeader,
      child: Align(
        alignment: Alignment.topLeft,
        child: Transform.translate(
          offset: offset,
          child: IgnorePointer(
            ignoring: _closing,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                alignment: _scaleAlignment,
                child: GestureDetector(
                  onTap: _handleTap,
                  child: Material(
                    elevation: elevation,
                    borderRadius: borderRadius,
                    shadowColor: isFocused
                        ? theme.colorScheme.primary.withValues(alpha: 0.3)
                        : null,
                    child: AnimatedContainer(
                      // No size animation here; it avoids overflow while minimizing.
                      duration: Duration.zero,
                      curve: Curves.linear,
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: borderRadius,
                        border: Border.all(
                          color: borderColor,
                          // Fall back to borderWidth when focusedBorderWidth is null
                          // or showFocusBorder is false.
                          width: (isFocused && config.showFocusBorder)
                              ? (config.focusedBorderWidth ??
                                  config.borderWidth)
                              : config.borderWidth,
                          style: ((isFocused && config.showFocusBorder
                                      ? (config.focusedBorderWidth ??
                                          config.borderWidth)
                                      : config.borderWidth) <=
                                  0)
                              ? BorderStyle.none
                              : BorderStyle.solid,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          // Same place in the tree whether open or minimized, so the
                          // content State (text, scroll position, and so on) survives.
                          Positioned(
                            key: const ValueKey('draggable-overlay-body'),
                            top: headerHeight + dividerHeight,
                            left: 0,
                            right: 0,
                            height: bodyHeight,
                            child: Offstage(
                              offstage: showMinimizedChrome,
                              child: TickerMode(
                                enabled: !showMinimizedChrome,
                                child: ExcludeFocus(
                                  excluding: showMinimizedChrome,
                                  child: _buildBody(
                                    draggable: !config.showHeader,
                                    borderRadius: bodyRadius,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (config.showHeader)
                            Positioned(
                              key: const ValueKey('draggable-overlay-header'),
                              top: 0,
                              left: 0,
                              right: 0,
                              height: config.minimizedHeight,
                              child: _buildHeader(
                                context,
                                isFocused,
                                expandHeight: false,
                              ),
                            ),
                          if (config.showHeader &&
                              config.showDivider &&
                              !showMinimizedChrome)
                            Positioned(
                              top: config.minimizedHeight,
                              left: 0,
                              right: 0,
                              height: config.dividerHeight,
                              child: Divider(
                                height: config.dividerHeight,
                                thickness: config.dividerHeight,
                                color: config.dividerColor ??
                                    borderColor.withValues(alpha: 0.5),
                              ),
                            ),

                          // Resize handles, only while expanded and resizable.
                          if (!showMinimizedChrome &&
                              !_controller.isMaximized &&
                              config.resizable &&
                              (config.resizeWidth || config.resizeHeight))
                            ..._buildResizeHandles(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildResizeHandles() {
    final config = widget.config;
    final handleSize = config.resizeHandleSize;
    final cornerSize = handleSize * 2;
    final allowWidth = config.resizeWidth;
    final allowHeight = config.resizeHeight;
    // With both axes, the corners sit on the ends. With one axis,
    // the free edge covers the whole side.
    final horizontalInset = allowWidth ? cornerSize : 0.0;
    final verticalInset = allowHeight ? cornerSize : 0.0;
    final handles = <Widget>[];

    if (allowHeight) {
      handles.add(
        Positioned(
          top: 0,
          left: horizontalInset,
          right: horizontalInset,
          height: handleSize,
          child: _buildResizeHandle(
            _ResizeDirection.top,
            SystemMouseCursors.resizeUp,
          ),
        ),
      );
      handles.add(
        Positioned(
          bottom: 0,
          left: horizontalInset,
          right: horizontalInset,
          height: handleSize,
          child: _buildResizeHandle(
            _ResizeDirection.bottom,
            SystemMouseCursors.resizeDown,
          ),
        ),
      );
    }

    if (allowWidth) {
      handles.add(
        Positioned(
          left: 0,
          top: verticalInset,
          bottom: verticalInset,
          width: handleSize,
          child: _buildResizeHandle(
            _ResizeDirection.left,
            SystemMouseCursors.resizeLeft,
          ),
        ),
      );
      handles.add(
        Positioned(
          right: 0,
          top: verticalInset,
          bottom: verticalInset,
          width: handleSize,
          child: _buildResizeHandle(
            _ResizeDirection.right,
            SystemMouseCursors.resizeRight,
          ),
        ),
      );
    }

    if (allowWidth && allowHeight) {
      handles.add(
        Positioned(
          top: 0,
          left: 0,
          width: cornerSize,
          height: cornerSize,
          child: _buildResizeHandle(
            _ResizeDirection.topLeft,
            SystemMouseCursors.resizeUpLeft,
          ),
        ),
      );
      handles.add(
        Positioned(
          top: 0,
          right: 0,
          width: cornerSize,
          height: cornerSize,
          child: _buildResizeHandle(
            _ResizeDirection.topRight,
            SystemMouseCursors.resizeUpRight,
          ),
        ),
      );
      handles.add(
        Positioned(
          bottom: 0,
          left: 0,
          width: cornerSize,
          height: cornerSize,
          child: _buildResizeHandle(
            _ResizeDirection.bottomLeft,
            SystemMouseCursors.resizeDownLeft,
          ),
        ),
      );
      handles.add(
        Positioned(
          bottom: 0,
          right: 0,
          width: cornerSize,
          height: cornerSize,
          child: _buildResizeHandle(
            _ResizeDirection.bottomRight,
            SystemMouseCursors.resizeDownRight,
          ),
        ),
      );
    }

    return handles;
  }

  Widget _buildResizeHandle(_ResizeDirection direction, MouseCursor cursor) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        onPanUpdate: (details) => _handleResize(direction, details),
        onPanStart: (details) {
          _cancelMotionForGesture();
          _controller.bringToFront();
          widget.onFocus?.call();
        },
        onPanEnd: (_) => _interacting = false,
        onPanCancel: () => _interacting = false,
        behavior: HitTestBehavior
            .opaque, // Keep the gesture from passing through to the parent.
        // This stops the gesture from leaking to the parent GestureDetector.
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildBody({
    required bool draggable,
    required BorderRadius borderRadius,
  }) {
    final config = widget.config;
    final child = config.enableScrolling
        ? SingleChildScrollView(
            padding: config.contentPadding,
            child: widget.content,
          )
        : Padding(
            padding: config.contentPadding,
            child: widget.content,
          );

    final clipped = ClipRRect(
      borderRadius: borderRadius,
      child: child,
    );

    if (!draggable) return clipped;

    // Without a header, the content itself is the drag area.
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _handleDragStart,
        onPanUpdate: _handleDrag,
        onPanEnd: (_) => _interacting = false,
        onPanCancel: () => _interacting = false,
        child: SizedBox.expand(child: clipped),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isFocused, {
    bool expandHeight = false,
  }) {
    final theme = Theme.of(context);
    final isMinimized = _controller.isMinimized;
    final config = widget.config;

    final headerColor = config.headerBackgroundColor ??
        (isFocused
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5));

    final padding =
        config.headerPadding ?? const EdgeInsets.symmetric(horizontal: 12);

    return GestureDetector(
      onPanStart: (details) {
        _handleDragStart(details);
      },
      onPanUpdate: _handleDrag,
      onPanEnd: (_) => _interacting = false,
      onPanCancel: () => _interacting = false,
      onDoubleTap: () {
        if (_controller.isMinimized) {
          _controller.restore();
          widget.onRestored?.call();
        } else {
          _controller.minimize();
          widget.onMinimized?.call();
        }
      },
      child: Container(
        // When expandHeight is true, leave the height unset so Expanded controls it.
        height: expandHeight ? null : config.minimizedHeight,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(config.borderRadius),
            bottom: isMinimized
                ? Radius.circular(config.borderRadius)
                : Radius.zero,
          ),
          color: headerColor,
        ),
        child: isMinimized
            ? _buildMinimizedHeader(theme, isFocused)
            : _buildExpandedHeader(theme, isFocused),
      ),
    );
  }

  Widget _buildMinimizedHeader(ThemeData theme, bool isFocused) {
    final defaultIconColor = isFocused ? theme.colorScheme.primary : null;
    final iconColor = widget.config.headerIconColor ?? defaultIconColor;
    final buttonsColor = widget.config.headerButtonsColor ?? iconColor;

    return Row(
      children: [
        Icon(widget.config.dragHandleIcon, size: 14, color: iconColor),
        if (widget.icon != null) ...[
          const SizedBox(width: 6),
          Icon(widget.icon, size: 16, color: iconColor),
        ],
        if (widget.title != null) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.title!,
              style: widget.config.headerTextStyle ??
                  theme.textTheme.titleSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const Spacer(),
        const SizedBox(width: 4),
        _buildHeaderButton(
          icon: widget.config.maximizeIcon,
          tooltip: 'Restaurar',
          onTap: () {
            _controller.restore();
            widget.onRestored?.call();
          },
          color: buttonsColor,
          isFocused: isFocused,
        ),
        const SizedBox(width: 2),
        _buildHeaderButton(
          icon: widget.config.closeIcon,
          tooltip: 'Fechar',
          onTap: _controller.hide,
          isClose: true,
          color: null, // The close button uses its own red, or the default.
          isFocused: isFocused,
        ),
      ],
    );
  }

  Widget _buildExpandedHeader(ThemeData theme, bool isFocused) {
    final defaultIconColor = isFocused ? theme.colorScheme.primary : null;
    final iconColor = widget.config.headerIconColor ?? defaultIconColor;
    // The expanded header uses the configured color.

    return Row(
      children: [
        Icon(widget.config.dragHandleIcon, size: 16, color: iconColor),
        if (widget.icon != null) ...[
          const SizedBox(width: 8),
          Icon(widget.icon, size: 20, color: iconColor),
        ],
        if (widget.title != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title!,
              style: widget.config.headerTextStyle ??
                  theme.textTheme.titleMedium?.copyWith(
                    fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else
          const Spacer(),
        _buildHeaderIconButton(
          icon: widget.config.minimizeIcon,
          tooltip: 'Minimizar',
          onPressed: () {
            _controller.minimize();
            widget.onMinimized?.call();
          },
          color: widget.config.headerButtonsColor,
        ),
        if (widget.config.canMaximize)
          _buildHeaderIconButton(
            icon: _controller.isMaximized
                ? widget.config.windowRestoreIcon
                : widget.config.windowMaximizeIcon,
            tooltip:
                _controller.isMaximized ? 'Restaurar tamanho' : 'Maximizar',
            onPressed: _controller.toggleMaximize,
            color: widget.config.headerButtonsColor,
          ),
        _buildHeaderIconButton(
          icon: widget.config.closeIcon,
          tooltip: 'Fechar',
          onPressed: _controller.hide,
          isClose: true,
        ),
      ],
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool isClose = false,
    bool isFocused = false,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: _ImmediateTapAction(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 24,
          height: 24,
          padding: const EdgeInsets.all(2),
          child: Icon(
            icon,
            size: 16,
            color: isClose ? Colors.red.shade400 : (color),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isClose = false,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: _ImmediateTapAction(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        hoverColor: isClose ? Colors.red.shade50 : null,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: isClose ? Colors.red.shade400 : color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Starts tap actions on pointer-down while retaining tap semantics for
/// keyboard and accessibility activation.
class _ImmediateTapAction extends StatefulWidget {
  const _ImmediateTapAction({
    required this.onTap,
    required this.child,
    this.borderRadius,
    this.hoverColor,
  });

  final VoidCallback onTap;
  final Widget child;
  final BorderRadius? borderRadius;
  final Color? hoverColor;

  @override
  State<_ImmediateTapAction> createState() => _ImmediateTapActionState();
}

class _ImmediateTapActionState extends State<_ImmediateTapAction> {
  final Set<int> _activePointers = {};

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointers.add(event.pointer)) widget.onTap();
  }

  void _handlePointerUp(PointerUpEvent event) {
    // Keep the pointer marked through the tap callback, which may be dispatched
    // after the raw pointer-up event on some platforms.
    Timer(const Duration(seconds: 1),
        () => _activePointers.remove(event.pointer));
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
  }

  void _handleTap() {
    if (_activePointers.isNotEmpty) {
      _activePointers.clear();
      return;
    }
    widget.onTap();
  }

  void _handleTapCancel() {
    _activePointers.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: InkWell(
        onTap: _handleTap,
        onTapCancel: _handleTapCancel,
        borderRadius: widget.borderRadius,
        hoverColor: widget.hoverColor,
        child: widget.child,
      ),
    );
  }
}

// ============================================================================
// WINDOW STACK
// ============================================================================

/// Stack that paints [windows] in [WindowManager] order.
///
/// The focused window is painted last, so it appears above the others.
/// [child] is painted behind every window and expands to fill the stack.
///
/// Give each [DraggableOverlayWindow] its own [Key]. This stack reorders the
/// same widget instances, and the key keeps their state.
class OverlayWindowStack extends StatefulWidget {
  /// Windows to show, drawn from back to front according to focus.
  final List<DraggableOverlayWindow> windows;

  /// Widget painted behind the windows, usually the page content.
  final Widget? child;

  /// Creates a stack for [windows], with an optional background [child].
  const OverlayWindowStack({super.key, required this.windows, this.child});

  @override
  State<OverlayWindowStack> createState() => _OverlayWindowStackState();
}

class _OverlayWindowStackState extends State<OverlayWindowStack> {
  final WindowManager _windowManager = WindowManager();

  @override
  void initState() {
    super.initState();
    _windowManager.addListener(_onWindowManagerChanged);
  }

  @override
  void dispose() {
    _windowManager.removeListener(_onWindowManagerChanged);
    super.dispose();
  }

  void _onWindowManagerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // A higher index is painted later, so it appears on top.
    final stackOrder = <String, int>{};
    for (int i = 0; i < _windowManager.windowStack.length; i++) {
      stackOrder[_windowManager.windowStack[i]] = i;
    }

    // Sort by z-index while keeping each window's key.
    final sortedWindows = List<DraggableOverlayWindow>.from(widget.windows);
    sortedWindows.sort((a, b) {
      final zIndexA = stackOrder[a.controller.windowId] ?? -1;
      final zIndexB = stackOrder[b.controller.windowId] ?? -1;
      return zIndexA.compareTo(zIndexB);
    });

    return SizedBox.expand(
      child: Stack(
        children: [
          if (widget.child != null) Positioned.fill(child: widget.child!),
          // Windows need the keys assigned where they are created.
          ...sortedWindows,
        ],
      ),
    );
  }
}
