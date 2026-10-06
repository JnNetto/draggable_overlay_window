# Draggable Overlay Window Example

The example app demonstrates the package features and includes an animation gallery for comparing transition styles.

## Features Demonstrated

- Multiple draggable windows with focus and z-order management
- Resizing on both axes or on width or height alone
- Minimize, restore, maximize, and unmaximize actions
- Headerless windows controlled through `DraggableWindowController`
- Window-specific animations for open, close, minimize, restore, maximize, and unmaximize
- An animation gallery with Fade, Zoom, Zoom from Corner, Elastic, Rectangle, Fast, and No Animation presets
- Custom styling, callbacks, and content state preservation while minimized

## Run the Example

```bash
cd example
flutter pub get
flutter run
```

## Try the Animation Gallery

Scroll to **Galeria de animações** and open one or more presets. Each button creates a separate window with its own `DraggableWindowAnimations` configuration. The windows open in staggered positions so they can remain visible together.

Use each window's header controls to compare close, minimize/restore, and maximize/unmaximize transitions. Drag and resize the windows to see how the rectangle-based transitions interact with different window frames.

## Code Structure

- `lib/main.dart` contains the example app, reusable demo window setup, and animation presets.
- Each preset configures the public `WindowTransitionStyle` API; no package internals are used by the gallery.
