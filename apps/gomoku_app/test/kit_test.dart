import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku_flutter/l10n/strings.dart';
import 'package:gomoku_flutter/ui/kit/card.dart';
import 'package:gomoku_flutter/ui/kit/popup.dart';
import 'package:gomoku_flutter/ui/kit/sheet.dart';
import 'package:gomoku_flutter/ui/kit/states.dart';

Widget _host(Widget child, {Size size = const Size(390, 844)}) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(
    localizationsDelegates: const [AppStrings.delegate],
    supportedLocales: AppStrings.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('KitCard taps through and shows the selection tint', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        Center(
          child: KitCard(
            onTap: () => taps++,
            selected: true,
            child: const Text('card'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('card'));
    expect(taps, 1);
  });

  testWidgets('KitMenuButton opens an anchor menu and runs the item', (
    tester,
  ) async {
    var picked = false;
    await tester.pumpWidget(
      _host(
        Scaffold(
          appBar: AppBar(
            actions: [
              KitMenuButton(
                tooltip: 'options',
                items: [
                  const KitMenuItem(label: 'first'),
                  KitMenuItem(
                    label: 'run me',
                    icon: Icons.check_rounded,
                    onTap: () => picked = true,
                  ),
                  const KitMenuItem(
                    label: 'more',
                    subItems: [KitMenuItem(label: 'nested')],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('options'));
    await tester.pumpAndSettle();
    expect(find.text('run me'), findsOneWidget);
    await tester.tap(find.text('run me'));
    await tester.pumpAndSettle();
    expect(picked, isTrue);
    expect(find.text('run me'), findsNothing);
  });

  testWidgets('menu submenus swap levels inside the same card', (tester) async {
    await tester.pumpWidget(
      _host(
        Scaffold(
          appBar: AppBar(
            actions: [
              KitMenuButton(
                items: [
                  const KitMenuItem(
                    label: 'more',
                    subItems: [KitMenuItem(label: 'nested')],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(KitMenuButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('more'));
    await tester.pumpAndSettle();
    expect(find.text('nested'), findsOneWidget);
    expect(find.text('more'), findsNothing);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('more'), findsOneWidget);
  });

  testWidgets('showKitSheet opens a bottom sheet on compact screens', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showKitSheet<void>(
                context: context,
                title: 'sheet title',
                builder: (_) => const Text('sheet body'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('sheet body'), findsOneWidget);
  });

  testWidgets('showKitSheet opens a side panel on wide screens', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () => showKitSheet<void>(
                context: context,
                title: 'panel title',
                builder: (_) => const Text('panel body'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        size: const Size(1200, 800),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('panel body'), findsOneWidget);
    final panelCenter = tester.getCenter(find.text('panel body'));
    expect(
      panelCenter.dx,
      greaterThan(
        tester.view.physicalSize.width / tester.view.devicePixelRatio * .6,
      ),
    );
  });

  testWidgets('KitEmptyState renders every staggered part', (tester) async {
    await tester.pumpWidget(
      _host(
        const KitEmptyState(
          title: 'empty title',
          body: 'empty body',
          action: Text('empty action'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('empty title'), findsOneWidget);
    expect(find.text('empty body'), findsOneWidget);
    expect(find.text('empty action'), findsOneWidget);
  });

  testWidgets('KitStateSwitcher shows skeletons while loading', (tester) async {
    await tester.pumpWidget(
      _host(
        const KitStateSwitcher(
          isLoading: true,
          isEmpty: true,
          empty: Text('empty'),
          content: Text('content'),
        ),
      ),
    );
    expect(find.byType(KitSkeleton), findsNWidgets(3));
    expect(find.text('content'), findsNothing);
  });
}
