import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'design/theme.dart';
import 'design/tokens.dart';
import 'l10n/strings.dart';
import 'state/app_state.dart';
import 'state/online.dart';
import 'state/settings.dart';
import 'ui/pages/history_page.dart';
import 'ui/pages/home_page.dart';
import 'ui/pages/lobby_page.dart';
import 'ui/pages/local_page.dart';
import 'ui/pages/me_page.dart';
import 'ui/pages/online_page.dart';
import 'ui/shell.dart';

class GomokuApp extends ConsumerStatefulWidget {
  const GomokuApp({super.key});
  @override
  ConsumerState<GomokuApp> createState() => _GomokuAppState();
}

class _GomokuAppState extends ConsumerState<GomokuApp>
    with WidgetsBindingObserver {
  late final GoRouter _router = GoRouter(
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const HomePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/lobby', builder: (_, _) => const LobbyPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/me',
                builder: (_, state) =>
                    MePage(returnTo: state.uri.queryParameters['returnTo']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/local', builder: (_, _) => const LocalPage()),
      GoRoute(
        path: '/join/:code',
        builder: (context, state) => SectionScaffold(
          title: context.strings.t('joinRoom'),
          child: LobbyPage(
            key: ValueKey(state.pathParameters['code']),
            initialCode: state.pathParameters['code']!,
          ),
        ),
      ),
      GoRoute(
        path: '/room/:id',
        builder: (_, state) => OnlinePage(
          key: ValueKey(state.pathParameters['id']),
          roomId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/history/:id',
        builder: (_, state) => ReplayPage(
          key: ValueKey(state.pathParameters['id']),
          recordId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(path: '/account', redirect: (_, _) => '/me'),
      GoRoute(path: '/settings', redirect: (_, _) => '/me'),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: FilledButton.icon(
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.home_rounded),
          label: Text(context.strings.t('returnHome')),
        ),
      ),
    ),
  );
  Timer? _syncTimer;
  @override
  void initState() {
    super.initState();
    // Every pushed page has a complete, independently restorable route. Keep
    // its URL visible so refresh, browser history and copied links agree.
    GoRouter.optionURLReflectsImperativeAPIs = true;
    WidgetsBinding.instance.addObserver(this);
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  Future<void> _refresh({bool resume = false}) async {
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (resume || auth.profile != null) {
      await ref.read(authProvider.notifier).restore(force: true);
    }
    if (!mounted) return;
    ref.invalidate(backendHealthProvider);
    if (resume) ref.invalidate(serviceConfigProvider);
    await ref.read(syncProvider.notifier).sync();
    if (resume && mounted) await ref.read(onlineProvider.notifier).reconnect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refresh(resume: true));
    }
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final locale = settings.language == 'system'
        ? AppStrings.resolveLocales(
            WidgetsBinding.instance.platformDispatcher.locales,
          )
        : Locale(settings.language);
    ref.watch(authProvider);
    return DynamicColorBuilder(
      builder: (light, dark) => DesignCapabilities(
        dynamicColor: light != null && dark != null,
        child: MaterialApp.router(
          title: 'Gomoku',
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          theme: AppTheme.build(
            Brightness.light,
            Color(settings.seed),
            dynamicScheme: settings.dynamicColor ? light : null,
            chinese: locale.languageCode == 'zh',
          ),
          darkTheme: AppTheme.build(
            Brightness.dark,
            Color(settings.seed),
            dynamicScheme: settings.dynamicColor ? dark : null,
            chinese: locale.languageCode == 'zh',
          ),
          themeMode: settings.theme,
          themeAnimationDuration:
              settings.reduceMotion ||
                  WidgetsBinding
                      .instance
                      .platformDispatcher
                      .accessibilityFeatures
                      .disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 280),
          supportedLocales: AppStrings.supportedLocales,
          locale: settings.language == 'system'
              ? null
              : Locale(settings.language),
          localeListResolutionCallback: (locales, _) =>
              AppStrings.resolveLocales(locales ?? []),
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations:
                  settings.reduceMotion ||
                  MediaQuery.disableAnimationsOf(context),
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
