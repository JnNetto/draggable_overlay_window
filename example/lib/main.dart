import 'dart:async';

import 'package:draggable_overlay_window/draggable_overlay_window.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Draggable Overlay Window Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class WindowItem {
  final String id;
  final DraggableWindowController controller;
  final Widget content;
  final DraggableWindowConfig config;
  final String title;
  final String? tag;

  WindowItem({
    required this.id,
    required this.controller,
    required this.content,
    required this.config,
    required this.title,
    this.tag,
  });
}

class _AnimationPreset {
  const _AnimationPreset({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.animations,
  });

  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final DraggableWindowAnimations animations;
}

const _animationPresets = <_AnimationPreset>[
  _AnimationPreset(
    name: 'Fade',
    description: 'A janela aparece e desaparece pela opacidade.',
    icon: Icons.opacity,
    color: Colors.blue,
    animations: DraggableWindowAnimations(
      open: WindowTransitionStyle(
        duration: Duration(milliseconds: 240),
        beginOpacity: 0,
        endOpacity: 1,
        animateRect: false,
      ),
      close: WindowTransitionStyle(
        duration: Duration(milliseconds: 200),
        beginOpacity: 1,
        endOpacity: 0,
        animateRect: false,
      ),
    ),
  ),
  _AnimationPreset(
    name: 'Zoom',
    description: 'Zoom central combinado com fade.',
    icon: Icons.zoom_in,
    color: Colors.deepPurple,
    animations: DraggableWindowAnimations(
      open: WindowTransitionStyle(
        duration: Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        beginOpacity: 0,
        beginScale: 0.55,
        endOpacity: 1,
        endScale: 1,
        animateRect: false,
      ),
      close: WindowTransitionStyle(
        duration: Duration(milliseconds: 200),
        curve: Curves.easeInCubic,
        beginOpacity: 1,
        beginScale: 1,
        endOpacity: 0,
        endScale: 0.7,
        animateRect: false,
      ),
    ),
  ),
  _AnimationPreset(
    name: 'Zoom do canto',
    description: 'A escala cresce a partir do canto superior esquerdo.',
    icon: Icons.north_west,
    color: Colors.teal,
    animations: DraggableWindowAnimations(
      open: WindowTransitionStyle(
        duration: Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        beginOpacity: 0,
        beginScale: 0.35,
        endOpacity: 1,
        endScale: 1,
        scaleAlignment: Alignment.topLeft,
        animateRect: false,
      ),
      close: WindowTransitionStyle(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeInBack,
        beginScale: 1,
        endScale: 0.35,
        scaleAlignment: Alignment.topLeft,
        animateRect: false,
      ),
    ),
  ),
  _AnimationPreset(
    name: 'Elástica',
    description: 'Curva elástica ao abrir e encolhimento ao fechar.',
    icon: Icons.waves,
    color: Colors.orange,
    animations: DraggableWindowAnimations(
      open: WindowTransitionStyle(
        duration: Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        beginOpacity: 0,
        beginScale: 0.4,
        endOpacity: 1,
        endScale: 1,
        animateRect: false,
      ),
      close: WindowTransitionStyle(
        duration: Duration(milliseconds: 180),
        curve: Curves.easeInBack,
        beginScale: 1,
        endScale: 0.65,
        animateRect: false,
      ),
      minimize: WindowTransitionStyle(
        duration: Duration(milliseconds: 260),
        curve: Curves.easeInBack,
        scaleAlignment: Alignment.topCenter,
      ),
      restore: WindowTransitionStyle(
        duration: Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        scaleAlignment: Alignment.topCenter,
      ),
    ),
  ),
  _AnimationPreset(
    name: 'Retângulo',
    description: 'Minimizar, restaurar e maximizar interpolam o retângulo.',
    icon: Icons.crop_free,
    color: Colors.indigo,
    animations: DraggableWindowAnimations(
      open: WindowTransitionStyle(
        duration: Duration(milliseconds: 220),
        beginOpacity: 0,
        beginScale: 0.94,
        endOpacity: 1,
        endScale: 1,
        animateRect: false,
      ),
      close: WindowTransitionStyle(
        duration: Duration(milliseconds: 180),
        beginOpacity: 1,
        endOpacity: 0,
        animateRect: false,
      ),
      minimize: WindowTransitionStyle(
        duration: Duration(milliseconds: 340),
        curve: Curves.easeInOutCubic,
        scaleAlignment: Alignment.topCenter,
      ),
      restore: WindowTransitionStyle(
        duration: Duration(milliseconds: 340),
        curve: Curves.easeInOutCubic,
        scaleAlignment: Alignment.topCenter,
      ),
      maximize: WindowTransitionStyle(
        duration: Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      ),
      unmaximize: WindowTransitionStyle(
        duration: Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      ),
    ),
  ),
  _AnimationPreset(
    name: 'Rápida',
    description: 'Transições curtas para comparar a resposta mais direta.',
    icon: Icons.bolt,
    color: Colors.red,
    animations: DraggableWindowAnimations(
      open: WindowTransitionStyle(
        duration: Duration(milliseconds: 80),
        beginOpacity: 0,
        beginScale: 0.95,
        endOpacity: 1,
        endScale: 1,
        animateRect: false,
      ),
      close: WindowTransitionStyle(
        duration: Duration(milliseconds: 70),
        beginOpacity: 1,
        endOpacity: 0,
        animateRect: false,
      ),
      minimize: WindowTransitionStyle(
        duration: Duration(milliseconds: 100),
        scaleAlignment: Alignment.topCenter,
      ),
      restore: WindowTransitionStyle(
        duration: Duration(milliseconds: 100),
        scaleAlignment: Alignment.topCenter,
      ),
      maximize: WindowTransitionStyle(
        duration: Duration(milliseconds: 120),
      ),
      unmaximize: WindowTransitionStyle(
        duration: Duration(milliseconds: 120),
      ),
    ),
  ),
  _AnimationPreset(
    name: 'Sem animação',
    description: 'Referência instantânea sem transições.',
    icon: Icons.skip_next,
    color: Colors.blueGrey,
    animations: DraggableWindowAnimations.none,
  ),
];

class _HomePageState extends State<HomePage> {
  final List<WindowItem> _windows = [];
  int _counter = 0;
  int _animationWindowCount = 0;

  void _addWindow(
    String title,
    Widget content,
    DraggableWindowConfig config, {
    Size? initialSize,
    Offset? initialPosition,
    String? tag,
  }) {
    // Agora o controller gerencia a unicidade!
    final controller = DraggableWindowController(
      initialSize: initialSize ?? const Size(300, 200),
      initialPosition: initialPosition ?? const Offset(50, 50),
      tag: tag, // Passando a tag para o controller
    );

    // Se a janela já existe na lista do usuário, apenas reutiliza-la
    final existingIndex =
        _windows.indexWhere((w) => w.controller == controller);

    if (existingIndex != -1) {
      final existingWindow = _windows[existingIndex];
      final wasVisible = existingWindow.controller.isVisible;
      existingWindow.controller.show();
      existingWindow.controller.bringToFront();
      if (existingWindow.controller.isMinimized) {
        existingWindow.controller.restore();
      }

      // hide() tira a janela da tela, mas o controller continua na lista.
      // Só avisa quando ela realmente já estava visível.
      if (wasVisible) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'A janela "$title" já está aberta (gerenciado pelo Controller)!'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Se é uma nova janela, adiciona à lista
    setState(() {
      _counter++;
      _windows.add(WindowItem(
        id: 'win_$_counter',
        controller:
            controller, // Este pode ser um novo ou um existente que ainda nao estava na lista
        content: content,
        config: config,
        title: title,
        tag: tag,
      ));
      controller.show();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.bringToFront();
      });
    });
  }

  void _removeWindow(WindowItem item) {
    setState(() {
      _windows.remove(item);
      // Importante: Dispose agora remove a instância do cache global do plugin
      item.controller.dispose();
    });
  }

  WindowItem? _windowByTag(String tag) {
    for (final window in _windows) {
      if (window.tag == tag) return window;
    }
    return null;
  }

  void _addAnimationWindow(_AnimationPreset preset) {
    final offsetIndex = _animationWindowCount++ % 4;
    _addWindow(
      preset.name,
      Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(preset.icon, size: 38, color: preset.color),
              const SizedBox(height: 12),
              Text(preset.description, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text(
                'Use os controles do cabeçalho para comparar as outras ações.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      DraggableWindowConfig(
        animations: preset.animations,
        headerBackgroundColor: preset.color,
        headerIconColor: Colors.white,
        headerTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        borderColor: preset.color,
        focusedBorderColor: preset.color,
      ),
      initialSize: const Size(300, 210),
      initialPosition: Offset(28 + offsetIndex * 24, 100 + offsetIndex * 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: OverlayWindowStack(
        windows: [
          for (final window in _windows)
            DraggableOverlayWindow(
              key: ValueKey(window.id),
              controller: window.controller,
              config: window.config,
              title: window.title,
              onClose: () => _removeWindow(window),
              content: window.content,
            ),
        ],
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 50),
            Text(
              'Teste de Janelas Flutuantes',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _ImmediateElevatedButton.icon(
                  icon: const Icon(Icons.window),
                  label: const Text('Padrão (Multi)'),
                  onPressed: () {
                    _addWindow(
                      'Simples',
                      const Center(
                        child: Text(
                          'Janela Padrão\nRedimensionável e Arrastável',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const DraggableWindowConfig(),
                      tag: null, // Múltiplas instâncias
                    );
                  },
                ),
                // _ImmediateElevatedButton.icon(
                //   icon: const Icon(Icons.person),
                //   label: const Text('Perfil (Único)'),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.blue.shade100,
                //   ),
                //   onPressed: () {
                //     _addWindow(
                //       'Perfil do Usuário',
                //       const UserProfileContent(),
                //       DraggableWindowConfig(
                //         headerBackgroundColor: Colors.blue.shade700,
                //         headerIconColor: Colors.white,
                //         enableScrolling: false,
                //         headerTextStyle: const TextStyle(
                //           color: Colors.white,
                //           fontWeight: FontWeight.bold,
                //         ),
                //       ),
                //       initialSize: const Size(350, 500),
                //       tag: 'profile', // Único
                //     );
                //   },
                // ),
                // _ImmediateElevatedButton.icon(
                //   icon: const Icon(Icons.sticky_note_2),
                //   label: const Text('Nota (Multi)'),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.yellow.shade100,
                //   ),
                //   onPressed: () {
                //     _addWindow(
                //       'Lembrete',
                //       Container(
                //         color: Colors.yellow.shade50,
                //         padding: const EdgeInsets.all(16),
                //         child: Column(
                //           crossAxisAlignment: CrossAxisAlignment.start,
                //           children: [
                //             Text(
                //               'Nota Rápida',
                //               style: TextStyle(
                //                 fontFamily: 'cursive',
                //                 fontSize: 24,
                //                 color: Colors.grey.shade800,
                //               ),
                //             ),
                //             const Divider(),
                //             const Text('Escreva algo...'),
                //           ],
                //         ),
                //       ),
                //       DraggableWindowConfig(
                //         windowBackgroundColor: Colors.yellow.shade50,
                //         headerBackgroundColor: Colors.yellow.shade700,
                //         borderColor: Colors.yellow.shade900,
                //         dividerColor: Colors.yellow.shade900,
                //         borderRadius: 0,
                //         elevation: 4,
                //       ),
                //       initialSize: const Size(200, 200),
                //       tag: null, // Múltiplas
                //     );
                //   },
                // ),
                // _ImmediateElevatedButton.icon(
                //   icon: const Icon(Icons.lock),
                //   label: const Text('Aviso (Único)'),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.red.shade100,
                //   ),
                //   onPressed: () {
                //     _addWindow(
                //       'Aviso Importante',
                //       const Center(
                //         child: Padding(
                //           padding: EdgeInsets.all(16.0),
                //           child: Column(
                //             mainAxisAlignment: MainAxisAlignment.center,
                //             children: [
                //               Icon(Icons.warning,
                //                   size: 40, color: Colors.orange),
                //               SizedBox(height: 10),
                //               Text(
                //                 'Esta é uma janela de alerta fixa.\nNão pode ser redimensionada.',
                //                 textAlign: TextAlign.center,
                //               ),
                //             ],
                //           ),
                //         ),
                //       ),
                //       DraggableWindowConfig(
                //         resizable: false,
                //         borderColor: Colors.red,
                //         headerBackgroundColor: Colors.red,
                //         headerIconColor: Colors.white,
                //         headerTextStyle: const TextStyle(color: Colors.white),
                //       ),
                //       initialSize: const Size(300, 200),
                //       tag: 'alert', // Único
                //     );
                //   },
                // ),
                // _ImmediateElevatedButton.icon(
                //   icon: const Icon(Icons.swap_horiz),
                //   label: const Text('Só largura'),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.teal.shade100,
                //   ),
                //   onPressed: () {
                //     _addWindow(
                //       'Só largura',
                //       const Center(
                //         child: Text(
                //           'Arraste as laterais.\nA altura fica fixa.',
                //           textAlign: TextAlign.center,
                //         ),
                //       ),
                //       const DraggableWindowConfig(
                //         resizeHeight: false,
                //         headerBackgroundColor: Colors.teal,
                //         headerIconColor: Colors.white,
                //         headerTextStyle: TextStyle(color: Colors.white),
                //       ),
                //       initialSize: const Size(360, 180),
                //       tag: null,
                //     );
                //   },
                // ),
                // _ImmediateElevatedButton.icon(
                //   icon: const Icon(Icons.swap_vert),
                //   label: const Text('Só altura'),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.indigo.shade100,
                //   ),
                //   onPressed: () {
                //     _addWindow(
                //       'Só altura',
                //       const Center(
                //         child: Text(
                //           'Arraste o topo ou a base.\nA largura fica fixa.',
                //           textAlign: TextAlign.center,
                //         ),
                //       ),
                //       const DraggableWindowConfig(
                //         resizeWidth: false,
                //         headerBackgroundColor: Colors.indigo,
                //         headerIconColor: Colors.white,
                //         headerTextStyle: TextStyle(color: Colors.white),
                //       ),
                //       initialSize: const Size(280, 320),
                //       tag: null,
                //     );
                //   },
                // ),
                // _ImmediateElevatedButton.icon(
                //   icon: const Icon(Icons.music_note),
                //   label: const Text('Player (Único)'),
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: Colors.grey.shade300,
                //   ),
                //   onPressed: () {
                //     _addWindow(
                //       'Now Playing',
                //       Container(
                //         color: Colors.black,
                //         child: Center(
                //           child: Icon(Icons.play_circle_fill,
                //               size: 64,
                //               color: Colors.white.withValues(alpha: 0.8)),
                //         ),
                //       ),
                //       const DraggableWindowConfig(
                //         windowBackgroundColor: Colors.black,
                //         headerBackgroundColor: Colors.black,
                //         headerIconColor: Colors.white,
                //         headerTextStyle: TextStyle(color: Colors.white),
                //         borderColor: Colors.grey,
                //         dividerColor: Colors.grey,
                //       ),
                //       initialSize: const Size(400, 225),
                //       tag: 'player', // Único
                //     );
                //   },
                // ),
                // _ImmediateElevatedButton.icon(
                //   icon: const Icon(Icons.code),
                //   label: const Text('Calc (Único)'),
                //   onPressed: () {
                //     _addWindow(
                //       'Meia Tela',
                //       const Center(child: Text('50% da largura da tela')),
                //       DraggableWindowConfig(
                //         widthCalculator: (screenWidth) => screenWidth * 0.5,
                //         heightCalculator: (screenHeight) => 200,
                //       ),
                //       initialPosition: const Offset(10, 300),
                //       tag: 'calculator', // Único
                //     );
                //   },
                // ),
                _ImmediateElevatedButton.icon(
                  icon: const Icon(Icons.rectangle),
                  label: const Text('Painel (só cor)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade200,
                  ),
                  onPressed: () {
                    _addWindow(
                      'Painel',
                      const SizedBox.expand(),
                      const DraggableWindowConfig(
                        minHeight: 1,
                        minWidth: 1,
                        showHeader: false,
                        enableScrolling: false,
                        contentPadding: EdgeInsets.zero,
                        windowBackgroundColor: Color(0xFF00897B),
                        borderWidth: 0,
                        showFocusBorder: false,
                        elevation: 4,
                        animations: DraggableWindowAnimations(
                          open: WindowTransitionStyle(
                            duration: Duration(milliseconds: 420),
                            curve: Curves.easeOutBack,
                            beginOpacity: 0,
                            beginScale: 0.4,
                            endScale: 1,
                            animateRect: false,
                          ),
                          close: WindowTransitionStyle(
                            duration: Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            endOpacity: 0,
                            endScale: 0.6,
                            animateRect: false,
                          ),
                        ),
                      ),
                      initialSize: const Size(220, 140),
                      tag: 'color-panel',
                    );
                  },
                ),
                _ImmediateElevatedButton.icon(
                  icon: const Icon(Icons.unfold_less),
                  label: const Text('Minimizar / restaurar painel'),
                  onPressed: () {
                    final panel = _windowByTag('color-panel');
                    if (panel == null || !panel.controller.isVisible) return;
                    panel.controller.toggleMinimize();
                  },
                ),
                _ImmediateElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Fechar painel'),
                  onPressed: () {
                    final panel = _windowByTag('color-panel');
                    panel?.controller.hide();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ImmediateElevatedButton extends StatefulWidget {
  const _ImmediateElevatedButton.icon({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.style,
  });

  final Widget icon;
  final Widget label;
  final VoidCallback onPressed;
  final ButtonStyle? style;

  @override
  State<_ImmediateElevatedButton> createState() =>
      _ImmediateElevatedButtonState();
}

class _ImmediateElevatedButtonState extends State<_ImmediateElevatedButton> {
  final Set<int> _activePointers = {};

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointers.add(event.pointer)) widget.onPressed();
  }

  void _handlePointerUp(PointerUpEvent event) {
    // Browser click callbacks can arrive after the raw pointer-up event.
    // Keep the marker until that callback consumes it, with a safety timeout
    // for releases that do not produce a tap (for example, outside the button).
    Timer(const Duration(seconds: 1),
        () => _activePointers.remove(event.pointer));
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
  }

  void _handlePressed() {
    if (_activePointers.isNotEmpty) return;
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.deferToChild,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: ElevatedButton.icon(
        icon: widget.icon,
        label: widget.label,
        style: widget.style,
        onPressed: _handlePressed,
      ),
    );
  }
}

class UserProfileContent extends StatefulWidget {
  const UserProfileContent({super.key});

  @override
  State<UserProfileContent> createState() => _UserProfileContentState();
}

class _UserProfileContentState extends State<UserProfileContent> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  bool _notifications = true;
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: 'Usuário Exemplo');
    _email = TextEditingController(text: 'email@exemplo.com');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CircleAvatar(
          radius: 40,
          child: Icon(Icons.person, size: 40),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Nome',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          controller: _name,
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          controller: _email,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Notificações'),
          value: _notifications,
          onChanged: (val) => setState(() => _notifications = val),
        ),
        SwitchListTile(
          title: const Text('Modo Escuro'),
          value: _darkMode,
          onChanged: (val) => setState(() => _darkMode = val),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {},
          child: const Text('Salvar'),
        ),
        const SizedBox(height: 200),
        const Center(child: Text("Final da lista")),
      ],
    );
  }
}
