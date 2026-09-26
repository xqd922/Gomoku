import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/shape.dart';
import '../../design/tokens.dart';
import '../../l10n/strings.dart';
import 'popup.dart';

/// The floating toolbar page shell: content scrolls beneath a rounded bar
/// that carries the title and the page actions. Actions beyond [maxActions]
/// fold into the overflow menu, the FlClash page pattern.
class KitScaffold extends StatefulWidget {
  const KitScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.menuItems = const [],
    this.showBack = false,
    this.fallback = '/',
    this.searchable = false,
    this.onSearch,
    this.searchHint,
    this.floatingActionButton,
  });

  final String title;
  final Widget child;

  /// Icon actions shown on the bar; extras fold into the overflow menu.
  final List<KitToolbarAction> actions;
  final List<KitMenuItem> menuItems;
  final bool showBack;
  final String fallback;
  final bool searchable;
  final ValueChanged<String>? onSearch;
  final String? searchHint;
  final Widget? floatingActionButton;

  /// Space the floating toolbar reserves above the content.
  static double get toolbarInset => 68;

  @override
  State<KitScaffold> createState() => _KitScaffoldState();
}

class _KitScaffoldState extends State<KitScaffold> {
  bool _searching = false;
  final _searchFocus = FocusNode();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _submitSearch(String value) => widget.onSearch?.call(value.trim());

  @override
  Widget build(BuildContext context) {
    final maxActions = MediaQuery.sizeOf(context).width >= AppLayout.compact
        ? 3
        : 2;
    final visible = widget.actions.take(maxActions).toList();
    final folded = widget.actions.skip(maxActions).toList();
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            top: 0,
            child: Padding(
              padding: EdgeInsets.only(
                top: KitScaffold.toolbarInset,
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: widget.child,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + AppSpacing.tight,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.content,
              ),
              child: _KitToolbar(
                title: widget.title,
                actions: visible,
                folded: [
                  ...folded.map(
                    (action) => KitMenuItem(
                      label: action.tooltip,
                      icon: action.icon,
                      onTap: action.onPressed,
                    ),
                  ),
                  ...widget.menuItems,
                ],
                showBack: widget.showBack,
                fallback: widget.fallback,
                searchable: widget.searchable,
                searchHint: widget.searchHint,
                searching: _searching,
                searchController: _searchController,
                searchFocus: _searchFocus,
                onToggleSearch: widget.searchable
                    ? () => setState(() {
                        if (_searching) {
                          _searchController.clear();
                          _submitSearch('');
                        }
                        _searching = !_searching;
                      })
                    : null,
                onSearch: _submitSearch,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}

class KitToolbarAction {
  const KitToolbarAction({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
}

class _KitToolbar extends StatelessWidget {
  const _KitToolbar({
    required this.title,
    required this.actions,
    required this.folded,
    required this.showBack,
    required this.fallback,
    required this.searchable,
    required this.searchHint,
    required this.searching,
    required this.searchController,
    required this.searchFocus,
    required this.onToggleSearch,
    required this.onSearch,
  });

  final String title;
  final List<KitToolbarAction> actions;
  final List<KitMenuItem> folded;
  final bool showBack;
  final String fallback;
  final bool searchable;
  final String? searchHint;
  final bool searching;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final VoidCallback? onToggleSearch;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow.withValues(alpha: .96),
      shape: AppShapes.pill,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            if (showBack) ...[
              IconButton(
                tooltip: context.strings.t('back'),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go(fallback),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ] else
              const SizedBox(width: AppSpacing.tight),
            if (searching && searchable)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: TextField(
                    controller: searchController,
                    focusNode: searchFocus,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: onSearch,
                    onChanged: onSearch,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      filled: false,
                      hintText: searchHint,
                    ),
                  ),
                ),
              )
            else ...[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.content),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              for (final action in actions)
                IconButton(
                  tooltip: action.tooltip,
                  onPressed: action.onPressed,
                  icon: Icon(action.icon),
                ),
              if (searchable)
                IconButton(
                  tooltip: context.strings.t('search'),
                  onPressed: onToggleSearch,
                  icon: Icon(
                    searching ? Icons.close_rounded : Icons.search_rounded,
                  ),
                ),
              if (folded.isNotEmpty)
                KitMenuButton(
                  tooltip: context.strings.t('gameOptions'),
                  items: folded,
                ),
            ],
            const SizedBox(width: AppSpacing.tight),
          ],
        ),
      ),
    );
  }
}
