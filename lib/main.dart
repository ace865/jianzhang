import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'core/controller.dart';
import 'core/database.dart';
import 'core/models.dart';
import 'ui/analysis.dart';
import 'ui/entry_editor.dart';
import 'ui/ledger.dart';
import 'ui/overview.dart';
import 'ui/settings.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Noto Serif SC',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const Startup());
}

class Startup extends StatefulWidget {
  const Startup({super.key});
  @override
  State<Startup> createState() => _StartupState();
}

class _StartupState extends State<Startup> {
  LedgerController? _controller;
  String? _error;
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (mounted) setState(() => _error = null);
    try {
      final database = await LedgerDatabase.open();
      final controller = LedgerController(database);
      await controller.initialize();
      if (mounted) setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _error = '账本暂时无法打开。请检查设备可用空间后重试，原有账本不会被清空。');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null) return LedgerApp(controller: _controller!);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ledgerTheme(false),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '简账',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 22),
                  if (_error == null)
                    const CircularProgressIndicator(strokeWidth: 2)
                  else ...[
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _initialize,
                      child: const Text('重试'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LedgerApp extends StatelessWidget {
  const LedgerApp({super.key, required this.controller});
  final LedgerController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MaterialApp(
      title: '简账',
      debugShowCheckedModeBanner: false,
      theme: ledgerTheme(false),
      darkTheme: ledgerTheme(true),
      themeMode: controller.dark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationDuration: Duration(
        milliseconds: controller.reducedMotion ? 0 : 180,
      ),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: LedgerShell(controller: controller),
    ),
  );
}

class LedgerShell extends StatefulWidget {
  const LedgerShell({super.key, required this.controller});
  final LedgerController controller;
  @override
  State<LedgerShell> createState() => _LedgerShellState();
}

class _LedgerShellState extends State<LedgerShell>
    with SingleTickerProviderStateMixin {
  final _ledgerKey = GlobalKey<LedgerScreenState>();
  final _visited = <int>{0};
  EntryFilter? _pendingFilter;
  int _index = 0;
  late AnimationController _animation;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _editorOpen = false;
  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
    final curve = CurvedAnimation(
      parent: _animation,
      curve: Curves.easeOutCubic,
    );
    _fade = Tween<double>(begin: 0.3, end: 1).animate(curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.015),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() {
      _index = index;
      _visited.add(index);
    });
    if (widget.controller.reducedMotion ||
        MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else {
      _animation.forward(from: 0);
    }
  }

  void _openLedger(EntryFilter filter) {
    _pendingFilter = filter;
    _ledgerKey.currentState?.applyFilter(filter);
    _select(1);
  }

  Future<void> _editor() async {
    if (_editorOpen || widget.controller.busy) return;
    _editorOpen = true;
    try {
      await showEntryEditor(context, widget.controller);
    } finally {
      _editorOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = InkColors.of(context);
    final pages = <Widget>[
      OverviewScreen(controller: widget.controller, openLedger: _openLedger),
      _visited.contains(1)
          ? LedgerScreen(
              key: _ledgerKey,
              controller: widget.controller,
              initialFilter: _pendingFilter,
            )
          : const SizedBox.shrink(),
      _visited.contains(2)
          ? AnalysisScreen(
              controller: widget.controller,
              openLedger: _openLedger,
            )
          : const SizedBox.shrink(),
      _visited.contains(3)
          ? SettingsScreen(controller: widget.controller)
          : const SizedBox.shrink(),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          (widget.controller.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: ink.background,
                systemNavigationBarDividerColor: Colors.transparent,
              ),
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: IndexedStack(
                index: _index,
                children: List.generate(
                  pages.length,
                  (i) => TickerMode(enabled: i == _index, child: pages[i]),
                ),
              ),
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: FilledButton.icon(
            key: const ValueKey('add-entry'),
            onPressed: widget.controller.busy ? null : _editor,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('记一笔'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(132, 44),
              padding: const EdgeInsets.symmetric(horizontal: 25),
              shape: const StadiumBorder(),
            ),
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: ink.panel,
            border: Border(top: BorderSide(color: ink.border, width: 0.7)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
              child: Row(
                children: List.generate(4, (i) {
                  final labels = ['总览', '账单', '分析', '设置'];
                  final icons = [
                    LucideIcons.house,
                    LucideIcons.receiptText,
                    LucideIcons.chartPie,
                    LucideIcons.settings2,
                  ];
                  return Expanded(
                    child: Semantics(
                      selected: _index == i,
                      button: true,
                      child: InkWell(
                        key: ValueKey('nav-$i'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _select(i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icons[i],
                                size: 22,
                                color: _index == i ? ink.accent : ink.muted,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                labels[i],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: _index == i
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: _index == i ? ink.accent : ink.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
