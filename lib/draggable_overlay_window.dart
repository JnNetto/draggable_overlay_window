import 'dart:async';

import 'package:flutter/material.dart';

/// # DraggableOverlayWindow v2.2
///
/// Um widget de janela flutuante arrastável, redimensionável e minimizável para Flutter.
/// Pode ser usado como uma janela de overlay em qualquer aplicação Flutter.
///
/// ## Características:
/// - ✅ Arrastável (drag & drop)
/// - ✅ Redimensionável (resize handles nos cantos e bordas) - pode ser desabilitado
/// - ✅ Eixos independentes: só largura, só altura, ou ambos
/// - ✅ Cabeçalho opcional: a janela pode ser só o conteúdo, sem barra
/// - ✅ Minimizável com callbacks onMinimized/onRestored
/// - ✅ Maximizável: ocupa o tamanho máximo e volta com folga para redimensionar
/// - ✅ Animações por ação (abrir, fechar, minimizar, restaurar, maximizar)
/// - ✅ Fechável
/// - ✅ Sistema de foco (z-index) - clique para trazer ao topo
/// - ✅ Responsivo (adapta-se a diferentes tamanhos de tela)
/// - ✅ Personalizável (título e ícone opcionais, cores, tamanhos)
/// - ✅ Mantém estado quando minimizado
/// - ✅ Key obrigatória para melhor controle do widget

// ============================================================================
// GERENCIADOR DE JANELAS (para controle de z-index/foco)
// ============================================================================

/// Gerenciador global de janelas para controlar z-index e foco
class WindowManager extends ChangeNotifier {
  static final WindowManager _instance = WindowManager._internal();
  factory WindowManager() => _instance;
  WindowManager._internal();

  final List<String> _windowStack = [];
  int _nextId = 0;

  /// Gera um ID único para uma nova janela
  String generateId() {
    return 'window_${_nextId++}';
  }

  final Map<String, String> _taggedWindows = {};

  /// Registra uma janela com uma tag opcional (para garantir unicidade)
  void registerWindow(String windowId, {String? tag}) {
    if (tag != null) {
      if (_taggedWindows.containsKey(tag)) {
        // Se a tag já existe e aponta para outro ID, atualiza
        // Mas idealmente, a UI deve verificar antes
      }
      _taggedWindows[tag] = windowId;
    }

    if (!_windowStack.contains(windowId)) {
      _windowStack.add(windowId);
      notifyListeners();
    }
  }

  /// Remove uma janela do gerenciador
  void unregisterWindow(String windowId) {
    final wasRegistered = _windowStack.remove(windowId);
    _taggedWindows.removeWhere((key, value) => value == windowId);
    if (wasRegistered) notifyListeners();
  }

  /// Verifica se existe uma janela com a tag fornecida
  String? getWindowIdByTag(String tag) {
    return _taggedWindows[tag];
  }

  /// Traz uma janela para o topo (foco)
  void bringToFront(String windowId) {
    if (_windowStack.isNotEmpty && _windowStack.last == windowId) return;
    if (_windowStack.remove(windowId)) {
      _windowStack.add(windowId);
      notifyListeners();
    }
  }

  /// Retorna o z-index de uma janela (maior = mais acima)
  int getZIndex(String windowId) {
    return _windowStack.indexOf(windowId);
  }

  /// Retorna se a janela está no topo
  bool isOnTop(String windowId) {
    return _windowStack.isNotEmpty && _windowStack.last == windowId;
  }

  /// Lista de todas as janelas ordenadas por z-index
  List<String> get windowStack => List.unmodifiable(_windowStack);
}

// ============================================================================
// ANIMAÇÕES
// ============================================================================

/// Como uma transição de janela se move.
///
/// [duration] zero desliga essa transição. [beginOpacity]/[endOpacity] e
/// [beginScale]/[endScale] controlam o fade e o zoom. [animateRect] interpola
/// posição e tamanho (minimizar, restaurar, maximizar e desmaximizar).
/// [scaleAlignment] diz de qual canto o zoom cresce.
class WindowTransitionStyle {
  final Duration duration;
  final Curve curve;
  final double beginOpacity;
  final double endOpacity;
  final double beginScale;
  final double endScale;
  final Alignment scaleAlignment;
  final bool animateRect;

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

  static const WindowTransitionStyle instant = WindowTransitionStyle(
    duration: Duration.zero,
  );

  WindowTransitionStyle copyWith({
    Duration? duration,
    Curve? curve,
    double? beginOpacity,
    double? endOpacity,
    double? beginScale,
    double? endScale,
    Alignment? scaleAlignment,
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

/// Animações de abrir, fechar, minimizar, restaurar, maximizar e desmaximizar.
///
/// Cada ação é um [WindowTransitionStyle] independente.
class DraggableWindowAnimations {
  final WindowTransitionStyle open;
  final WindowTransitionStyle close;
  final WindowTransitionStyle minimize;
  final WindowTransitionStyle restore;
  final WindowTransitionStyle maximize;
  final WindowTransitionStyle unmaximize;

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

  /// Nenhuma ação anima.
  static const DraggableWindowAnimations none = DraggableWindowAnimations(
    open: WindowTransitionStyle.instant,
    close: WindowTransitionStyle.instant,
    minimize: WindowTransitionStyle.instant,
    restore: WindowTransitionStyle.instant,
    maximize: WindowTransitionStyle.instant,
    unmaximize: WindowTransitionStyle.instant,
  );

  DraggableWindowAnimations copyWith({
    WindowTransitionStyle? open,
    WindowTransitionStyle? close,
    WindowTransitionStyle? minimize,
    WindowTransitionStyle? restore,
    WindowTransitionStyle? maximize,
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
// CONFIGURAÇÕES
// ============================================================================

/// Configurações personalizáveis para o DraggableOverlayWindow
class DraggableWindowConfig {
  /// Altura da janela quando minimizada (apenas header)
  final double minimizedHeight;

  /// Raio das bordas arredondadas
  final double borderRadius;

  /// Elevação (sombra) da janela
  final double elevation;

  /// Elevação quando a janela está em foco
  final double focusedElevation;

  /// Cor de fundo do cabeçalho
  final Color? headerBackgroundColor;

  /// Cor de fundo da janela
  final Color? windowBackgroundColor;

  /// Cor da borda
  final Color? borderColor;

  /// Cor da borda quando em foco
  final Color? focusedBorderColor;

  /// Se deve habilitar rolagem automática no conteúdo
  final bool enableScrolling;

  /// Padding do conteúdo
  final EdgeInsets contentPadding;

  /// Se a janela pode ser redimensionada
  final bool resizable;

  /// Se a largura pode mudar ao arrastar as bordas.
  /// Só tem efeito quando [resizable] é true.
  final bool resizeWidth;

  /// Se a altura pode mudar ao arrastar as bordas.
  /// Só tem efeito quando [resizable] é true.
  final bool resizeHeight;

  /// Tamanho da área de arraste para redimensionar
  final double resizeHandleSize;

  /// Largura mínima da janela
  final double minWidth;

  /// Altura mínima da janela
  final double minHeight;

  /// Largura máxima da janela (null = sem limite)
  final double? maxWidth;

  /// Altura máxima da janela (null = sem limite)
  final double? maxHeight;

  /// Largura inicial da janela
  final double initialWidth;

  /// Altura inicial da janela
  final double initialHeight;

  /// Função para calcular a largura baseada na largura da tela (sobrescreve initialWidth)
  final double Function(double screenWidth)? widthCalculator;

  /// Função para calcular a altura baseada na altura da tela (sobrescreve initialHeight)
  final double Function(double screenHeight)? heightCalculator;

  /// Ícone do minimizar
  final IconData minimizeIcon;

  /// Ícone do maximizar/restaurar a partir do estado minimizado
  final IconData maximizeIcon;

  /// Ícone do botão que maximiza a janela
  final IconData windowMaximizeIcon;

  /// Ícone do botão que sai da maximização
  final IconData windowRestoreIcon;

  /// Ícone de fechar
  final IconData closeIcon;

  /// Ícone de arrastar
  final IconData dragHandleIcon;

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

  /// Largura da borda
  final double borderWidth;

  /// Largura da borda quando em foco
  final double? focusedBorderWidth;

  /// Se deve mostrar a borda de foco
  final bool showFocusBorder;

  /// Altura (espessura) do divisor
  final double dividerHeight;

  /// Se deve mostrar o divisor
  final bool showDivider;

  /// Se deve mostrar a barra superior (título, arraste, minimizar e fechar).
  /// Com false, a janela é só o conteúdo. Fechar, minimizar e restaurar
  /// continuam disponíveis no [DraggableWindowController].
  final bool showHeader;

  /// Se o botão de maximizar faz sentido para esta configuração.
  bool get canMaximize => resizable && (resizeWidth || resizeHeight);

  /// Cor do divisor
  final Color? dividerColor;

  /// Padding do conteúdo do header
  final EdgeInsets? headerPadding;

  /// Cor dos ícones do header
  final Color? headerIconColor;

  /// Cor dos botões do header
  final Color? headerButtonsColor;

  /// Estilo do texto do header
  final TextStyle? headerTextStyle;

  /// Animações de abrir, fechar, minimizar, restaurar, maximizar e desmaximizar.
  final DraggableWindowAnimations animations;

  /// Configuração padrão
  static const DraggableWindowConfig defaultConfig = DraggableWindowConfig();

  /// Configuração compacta para telas menores
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

  /// Cria uma cópia com valores alterados
  DraggableWindowConfig copyWith({
    double? minimizedHeight,
    double? borderRadius,
    double? elevation,
    double? focusedElevation,
    Color? headerBackgroundColor,
    Color? windowBackgroundColor,
    Color? borderColor,
    Color? focusedBorderColor,
    bool? enableScrolling,
    EdgeInsets? contentPadding,
    bool? resizable,
    bool? resizeWidth,
    bool? resizeHeight,
    double? resizeHandleSize,
    double? minWidth,
    double? minHeight,
    double? maxWidth,
    double? maxHeight,
    double? initialWidth,
    double? initialHeight,
    double Function(double screenWidth)? widthCalculator,
    double Function(double screenHeight)? heightCalculator,
    IconData? minimizeIcon,
    IconData? maximizeIcon,
    IconData? windowMaximizeIcon,
    IconData? windowRestoreIcon,
    IconData? closeIcon,
    IconData? dragHandleIcon,
    double? borderWidth,
    double? focusedBorderWidth,
    bool? showFocusBorder,
    double? dividerHeight,
    bool? showDivider,
    bool? showHeader,
    Color? dividerColor,
    EdgeInsets? headerPadding,
    Color? headerIconColor,
    Color? headerButtonsColor,
    TextStyle? headerTextStyle,
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
/// Controller para controlar o DraggableOverlayWindow programaticamente
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

  /// Construtor Factory
  /// Se [tag] for fornecido e já existir uma instância, retorna a existente.
  factory DraggableWindowController({
    Size initialSize = const Size(400, 350),
    Offset initialPosition = const Offset(80, 100),
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

  /// ID único da janela
  String get windowId => _windowId;

  /// Se a janela está visível
  bool get isVisible => _isVisible;

  /// Se a janela está minimizada
  bool get isMinimized => _isMinimized;

  /// Se a janela está maximizada
  bool get isMaximized => _isMaximized;

  /// Posição atual da janela
  Offset get position => _position;

  /// Tamanho atual da janela
  Size get size => _size;

  /// Se a janela está em foco (no topo)
  bool get isFocused => WindowManager().isOnTop(_windowId);

  /// Mostra a janela
  void show() {
    if (!_isVisible) {
      _isVisible = true;
      _isMinimized = false;
      WindowManager().registerWindow(_windowId, tag: _tag);
      WindowManager().bringToFront(_windowId);
      notifyListeners();
    }
  }

  /// Esconde a janela
  void hide() {
    if (_isVisible) {
      _isVisible = false;
      WindowManager().unregisterWindow(_windowId);
      notifyListeners();
    }
  }

  /// Alterna visibilidade
  void toggle() {
    if (_isVisible) {
      hide();
    } else {
      show();
    }
  }

  /// Minimiza a janela
  void minimize() {
    if (_isVisible && !_isMinimized) {
      _isMinimized = true;
      notifyListeners();
    }
  }

  /// Restaura a janela minimizada
  void restore() {
    if (_isVisible && _isMinimized) {
      _isMinimized = false;
      notifyListeners();
    }
  }

  /// Ocupa a largura e a altura máximas nos eixos redimensionáveis.
  /// Se estiver minimizada, também restaura.
  void maximize() {
    if (!_isVisible || _isMaximized) return;
    _isMinimized = false;
    _isMaximized = true;
    notifyListeners();
  }

  /// Sai da maximização. O widget devolve o tamanho anterior e, se ele
  /// estiver colado no máximo, reduz um pouco para sobrar borda de resize.
  void unmaximize() {
    if (!_isMaximized) return;
    _isMaximized = false;
    notifyListeners();
  }

  /// Alterna entre maximizado e o tamanho anterior
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

  /// Alterna estado minimizado
  void toggleMinimize() {
    if (_isVisible) {
      _isMinimized = !_isMinimized;
      notifyListeners();
    }
  }

  /// Traz a janela para o topo (foco)
  void bringToFront() {
    WindowManager().bringToFront(_windowId);
  }

  /// Define a posição da janela
  void setPosition(Offset newPosition) {
    if (_position != newPosition) {
      _position = newPosition;
      notifyListeners();
    }
  }

  /// Define o tamanho da janela
  void setSize(Size newSize) {
    if (_size != newSize) {
      _size = newSize;
      notifyListeners();
    }
  }

  /// Define posição e tamanho sem notificar (usado na inicialização)
  void setInitialState({Offset? position, Size? size}) {
    if (position != null) _position = position;
    if (size != null) _size = size;
  }

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
// ENUMS
// ============================================================================

/// Direção de redimensionamento
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
// WIDGET PRINCIPAL
// ============================================================================

/// Widget de janela flutuante arrastável e redimensionável
class DraggableOverlayWindow extends StatefulWidget {
  /// Controller para controle programático
  final DraggableWindowController controller;

  /// Título exibido no cabeçalho (opcional)
  final String? title;

  /// Ícone exibido no cabeçalho (opcional)
  final IconData? icon;

  /// Conteúdo da janela
  final Widget content;

  /// Configurações personalizadas
  final DraggableWindowConfig config;

  /// Callback quando a janela ganha foco
  final VoidCallback? onFocus;

  /// Callback quando a janela é fechada
  final VoidCallback? onClose;

  /// Callback quando a janela é minimizada
  final VoidCallback? onMinimized;

  /// Callback quando a janela é restaurada (maximizada)
  final VoidCallback? onRestored;

  /// Callback quando a posição muda
  final ValueChanged<Offset>? onPositionChanged;

  /// Callback quando o tamanho muda
  final ValueChanged<Size>? onSizeChanged;

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

  /// Folga mínima, em cada lado, ao sair de uma janela colada no máximo.
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
    // Usa o tamanho do controller se já definido, senão usa o config
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
    // Usar minimizedHeight quando minimizado
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

    // Posição e tamanho atuais
    double left = _currentPosition.dx;
    double top = _currentPosition.dy;
    double width = _currentSize.width;
    double height = _currentSize.height;

    if (allowWidth) {
      switch (direction) {
        case _ResizeDirection.left:
        case _ResizeDirection.topLeft:
        case _ResizeDirection.bottomLeft:
          // Ao redimensionar pela esquerda, mover a borda esquerda
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
          // Ao redimensionar pelo topo, mover a borda superior
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

    // Aplicar limites de tamanho mínimo
    if (allowWidth && width < config.minWidth) {
      if (direction == _ResizeDirection.left ||
          direction == _ResizeDirection.topLeft ||
          direction == _ResizeDirection.bottomLeft) {
        // Se estamos redimensionando pela esquerda e atingimos o mínimo,
        // ajustar a posição left para manter o tamanho mínimo
        left = _currentPosition.dx + (_currentSize.width - config.minWidth);
      }
      width = config.minWidth;
    }

    if (allowHeight && height < config.minHeight) {
      if (direction == _ResizeDirection.top ||
          direction == _ResizeDirection.topLeft ||
          direction == _ResizeDirection.topRight) {
        // Se estamos redimensionando pelo topo e atingimos o mínimo,
        // ajustar a posição top para manter o tamanho mínimo
        top = _currentPosition.dy + (_currentSize.height - config.minHeight);
      }
      height = config.minHeight;
    }

    // Aplicar limites de tamanho máximo
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

    // Garantir que não saia da tela
    if (allowWidth && left < 0) {
      width += left;
      left = 0;
    }
    if (allowHeight && top < 0) {
      height += top;
      top = 0;
    }

    // Garantir que a borda direita não ultrapasse a tela
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

    // Garantir que a borda inferior não ultrapasse a tela
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

    // O eixo desligado permanece exatamente como estava.
    if (!allowWidth) {
      left = _currentPosition.dx;
      width = _currentSize.width;
    }
    if (!allowHeight) {
      top = _currentPosition.dy;
      height = _currentSize.height;
    }

    // Atualizar estado
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
    // Enquanto a altura anima, o conteúdo continua visível e é cortado.
    final showMinimizedChrome = isMinimized && !animating;
    final isFocused = _windowManager.isOnTop(_controller.windowId);
    final config = widget.config;
    // Com barra, a janela não fica menor que o cabeçalho.
    // Sem barra, o piso é só minHeight.
    var heightFloor = config.minHeight;
    if (config.showHeader) {
      final chrome = config.minimizedHeight +
          (config.showDivider ? config.dividerHeight : 0);
      if (chrome > heightFloor) heightFloor = chrome;
    }
    // Altura real do conteúdo. No minimizar a janela encolhe,
    // mas o miolo continua com esse tamanho para o State não ser recriado.
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

    // Uso de Align + Transform evita erros de ParentData no Stack
    // e garante que a origem seja (0,0) para o offset funcionar corretamente.
    // Offstage na raiz só esconde a janela sem barra: o filho permanece montado.
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
                      // Sem animação para evitar problemas de overflow
                      duration: Duration.zero,
                      curve: Curves.linear,
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: borderRadius,
                        border: Border.all(
                          color: borderColor,
                          // Se focusedBorderWidth não for definido, usa borderWidth
                          // Se showFocusBorder for false, usa borderWidth
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
                          // Mesmo lugar na árvore aberto ou minimizado, para o State
                          // do conteúdo (texto, rolagem, etc.) sobreviver.
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

                          // Resize handles (apenas se não estiver minimizado e resizable)
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
    // Com os dois eixos, os cantos ocupam as pontas. Com um eixo só,
    // a borda livre cobre o lado inteiro.
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
            .opaque, // MUDANÇA CRÍTICA: de translucent para opaque
        // Isso impede que o gesto "vaze" para o GestureDetector pai
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

    // Sem a barra, o próprio conteúdo é a área de arraste.
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
        // Quando expandHeight é true, não definir altura fixa (deixa o Expanded controlar)
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
          color: null, // Fecha sempre tem cor propria ou usa padrao
          isFocused: isFocused,
        ),
      ],
    );
  }

  Widget _buildExpandedHeader(ThemeData theme, bool isFocused) {
    final defaultIconColor = isFocused ? theme.colorScheme.primary : null;
    final iconColor = widget.config.headerIconColor ?? defaultIconColor;
    // Para Expanded, usa a cor definida

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
// WIDGET CONTAINER (para gerenciar múltiplas janelas com z-index correto)
// ============================================================================

/// Container que gerencia múltiplas janelas com z-index automático.
/// A janela focada é pintada por último e fica por cima das outras.
class OverlayWindowStack extends StatefulWidget {
  /// Lista de janelas a serem exibidas
  final List<DraggableOverlayWindow> windows;

  /// Conteúdo principal (abaixo das janelas)
  final Widget? child;

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
    // Índice maior = desenhada por último = por cima.
    final stackOrder = <String, int>{};
    for (int i = 0; i < _windowManager.windowStack.length; i++) {
      stackOrder[_windowManager.windowStack[i]] = i;
    }

    // Ordenar as janelas pelo z-index MAS manteremos a mesma key
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
          // CORREÇÃO: As janelas devem ter keys atribuídas na criação
          ...sortedWindows,
        ],
      ),
    );
  }
}
