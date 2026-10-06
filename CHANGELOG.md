# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-23

### Added
- Initial release of Draggable Overlay Window
- Draggable windows with smooth interactions
- Resizable windows from all edges and corners
- Minimize and restore functionality
- Focus management with automatic z-index
- Programmatic control via `DraggableWindowController`
- Rich set of event callbacks (`onFocus`, `onClose`, `onMinimized`, `onRestored`, `onPositionChanged`, `onSizeChanged`)
- Highly customizable appearance (colors, borders, shadows, icons)
- Optional title and icon support
- Non-resizable window option
- Multiple window support with `OverlayWindowStack`
- Dynamic sizing with width/height calculators
- Responsive design for all platforms
- Comprehensive documentation and examples
- Full platform support (Android, iOS, Web, Windows, macOS, Linux)

### Technical Details
- No animations to prevent overflow issues
- Automatic constraint validation with `clamp`
- Optimized for web with `SizedBox.expand` in `OverlayWindowStack`
- Clean, maintainable code architecture
- Required `key` parameter for proper widget management

### Breaking Changes
- None (initial release)

## [1.1.0] - 2026-10-02

### Added
- Independent width and height resizing through `resizeWidth` and `resizeHeight`
- Headerless windows with `showHeader: false`; visibility and minimize controls remain available through `DraggableWindowController`
- Maximize and unmaximize actions (`maximize`, `unmaximize`, and `toggleMaximize`) for resizable axes, restoring the previous frame when unmaximized
- Per-action animations using `DraggableWindowAnimations` and `WindowTransitionStyle` for opening, closing, minimizing, restoring, maximizing, and unmaximizing
- Animation controls for duration, curve, opacity, scale, scale alignment, and rectangle interpolation
- Example gallery with fade, zoom, corner zoom, elastic, rectangle, fast, and no-animation presets

### Improved
- Header actions begin responding on pointer-down for immediate visual feedback
- Focus management avoids redundant notifications when the focused window is already at the top
- Close animations continue to completion if a drag or resize gesture overlaps the close action

### Fixed
- Correct z-order updates when focusing windows in `OverlayWindowStack`
- Minimized windows preserve their content state until they are closed
- Close animations are protected from drag and resize gesture interruption

### Compatibility
- No breaking API changes from 1.0.0
