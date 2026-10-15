import 'package:flutter/material.dart';
import 'package:wallet/l10n/app_localizations.dart';

import 'bottom_sheet_pinned_title.dart';
import 'swipeable_list_tile.dart';

/// Swipe edit/delete for searchable id+name pickers (category, tag).
class SearchablePickerSwipeActions {
  const SearchablePickerSwipeActions({
    required this.onEditItem,
    required this.confirmDeleteItem,
    required this.deleteItem,
  });

  final Future<void> Function(
    BuildContext sheetContext,
    ({String id, String name}) item,
  )
  onEditItem;
  final Future<bool> Function(
    BuildContext sheetContext,
    ({String id, String name}) item,
  )
  confirmDeleteItem;
  final Future<bool> Function(({String id, String name}) item) deleteItem;
}

/// Delete confirmation used by picker swipe actions.
Future<bool> confirmDeletePickerTitle(
  BuildContext context,
  AppLocalizations l10n, {
  required String title,
  required String message,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Picks an id from a searchable list. Items are shown in alphabetical order by [name].
/// Returns `null` if dismissed, `''` if [allowNone] and user cleared.
///
/// Use [getItems] so each build reads the parent's current lists. The modal sheet [builder] can rerun
/// when the parent rebuilds after [reloadItems]; snapshots in the outer closure would stay stale.
Future<String?> showSearchableIdPickerSheet(
  BuildContext context, {
  required AppLocalizations l10n,
  required String title,
  required String searchHint,
  required String noResultsMessage,
  required String emptyMessage,
  required bool allowNone,
  required List<({String id, String name})> Function() getItems,
  Future<void> Function(BuildContext sheetContext)? onAddPressed,
  String? addTooltip,
  Future<void> Function()? reloadItems,
  SearchablePickerSwipeActions? swipe,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    builder: (sheetContext) => _SearchableIdPickerSheet(
      l10n: l10n,
      sheetContext: sheetContext,
      title: title,
      searchHint: searchHint,
      noResultsMessage: noResultsMessage,
      emptyMessage: emptyMessage,
      allowNone: allowNone,
      getItems: getItems,
      onAddPressed: onAddPressed,
      addTooltip: addTooltip,
      reloadItems: reloadItems,
      swipe: swipe,
    ),
  );
}

/// Search/filter state lives here—not in [showModalBottomSheet]'s [builder], which can rebuild when
/// the keyboard opens ([MediaQuery] view inset changes) and would reset stray locals otherwise.
class _SearchableIdPickerSheet extends StatefulWidget {
  const _SearchableIdPickerSheet({
    required this.l10n,
    required this.sheetContext,
    required this.title,
    required this.searchHint,
    required this.noResultsMessage,
    required this.emptyMessage,
    required this.allowNone,
    required this.getItems,
    this.onAddPressed,
    this.addTooltip,
    this.reloadItems,
    this.swipe,
  });

  final AppLocalizations l10n;
  final BuildContext sheetContext;
  final String title;
  final String searchHint;
  final String noResultsMessage;
  final String emptyMessage;
  final bool allowNone;
  final List<({String id, String name})> Function() getItems;
  final Future<void> Function(BuildContext sheetContext)? onAddPressed;
  final String? addTooltip;
  final Future<void> Function()? reloadItems;
  final SearchablePickerSwipeActions? swipe;

  @override
  State<_SearchableIdPickerSheet> createState() =>
      _SearchableIdPickerSheetState();
}

class _SearchableIdPickerSheetState extends State<_SearchableIdPickerSheet> {
  bool _showSearchField = false;
  String _searchFilter = '';

  List<({String id, String name})> _visible() {
    final items = [...widget.getItems()]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final q = _searchFilter.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _refreshItems() async {
    final r = widget.reloadItems;
    if (r == null) return;
    await r();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final sheetContext = widget.sheetContext;
    final allItems = widget.getItems();
    final list = _visible();

    final themeSheet = Theme.of(sheetContext);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.55,
          ),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                centerTitle: true,
                automaticallyImplyLeading: false,
                elevation: 0,
                scrolledUnderElevation: 4,
                backgroundColor: modalBottomSheetSurfaceColor(sheetContext),
                shadowColor: Theme.of(sheetContext).colorScheme.shadow,
                leading: modalBottomSheetBackButton(sheetContext),
                title: Text(
                  widget.title,
                  style: themeSheet.textTheme.titleLarge,
                ),
                actions: [
                  IconButton(
                    tooltip: widget.l10n.transferAccountSearch,
                    icon: Icon(
                      _showSearchField
                          ? Icons.search_off_outlined
                          : Icons.search,
                    ),
                    onPressed: () {
                      setState(() {
                        _showSearchField = !_showSearchField;
                        if (!_showSearchField) _searchFilter = '';
                      });
                    },
                  ),
                  if (widget.onAddPressed != null)
                    IconButton(
                      tooltip: widget.addTooltip ?? '',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () async {
                        await widget.onAddPressed!(sheetContext);
                        await _refreshItems();
                      },
                    ),
                ],
              ),
              if (widget.allowNone)
                SliverToBoxAdapter(
                  child: ListTile(
                    title: Text(widget.l10n.none),
                    leading: const Icon(Icons.clear),
                    onTap: () => Navigator.of(sheetContext).pop(''),
                  ),
                ),
              if (_showSearchField)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        prefixIcon: const Icon(Icons.search, size: 22),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: (v) => setState(() => _searchFilter = v),
                    ),
                  ),
                ),
              if (allItems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(widget.emptyMessage)),
                )
              else if (list.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(widget.noResultsMessage)),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final e = list[index];
                    final swipe = widget.swipe;
                    if (swipe == null) {
                      return ListTile(
                        title: Text(e.name),
                        onTap: () => Navigator.of(sheetContext).pop(e.id),
                      );
                    }
                    final actions = swipe;
                    return SwipeableListTile(
                      itemKey: e.id,
                      title: Text(e.name),
                      onTap: () => Navigator.of(sheetContext).pop(e.id),
                      onEdit: () {
                        Future(() async {
                          await actions.onEditItem(sheetContext, e);
                          if (!sheetContext.mounted) return;
                          await _refreshItems();
                        });
                      },
                      confirmDelete: () =>
                          actions.confirmDeleteItem(sheetContext, e),
                      onDelete: () async {
                        final ok = await actions.deleteItem(e);
                        if (ok) await _refreshItems();
                        return ok;
                      },
                    );
                  }, childCount: list.length),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
