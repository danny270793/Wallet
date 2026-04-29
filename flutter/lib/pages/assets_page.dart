import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wallet/l10n/app_localizations.dart';

import '../core/di/injection.dart';
import '../core/format_asset_holding_duration.dart';
import '../features/assets/domain/entities/asset_entity.dart';
import '../features/assets/presentation/cubit/assets_cubit.dart';
import '../features/assets/presentation/cubit/assets_state.dart';
import '../widgets/asset_editor_sheet.dart';
import '../widgets/shell_scaffold.dart';
import '../widgets/swipeable_list_tile.dart';

class AssetsPage extends StatelessWidget {
  const AssetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AssetsCubit>()..load(),
      child: const _AssetsView(),
    );
  }
}

class _AssetsView extends StatelessWidget {
  const _AssetsView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<AssetsCubit, AssetsState>(
      listener: (context, state) {
        if (state is AssetsActionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.unexpectedError)),
          );
        }
      },
      builder: (context, state) {
        return ShellScaffold(
          title: l10n.assets,
          floatingActionButton: FloatingActionButton(
            onPressed: () => showAssetEditorBottomSheet(
              context,
              l10n,
              cubit: context.read<AssetsCubit>(),
            ),
            child: const Icon(Icons.add),
          ),
          body: _body(context, state, l10n),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    AssetsState state,
    AppLocalizations l10n,
  ) {
    Future<void> pullRefresh() =>
        context.read<AssetsCubit>().load(showLoading: false);

    Future<void> reloadWithOverlay() =>
        context.read<AssetsCubit>().load(showLoading: true);

    if (state is AssetsLoading || state is AssetsInitial) {
      return RefreshIndicator(
        onRefresh: pullRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      );
    }

    if (state is AssetsError) {
      return RefreshIndicator(
        onRefresh: pullRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.unexpectedError),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: reloadWithOverlay,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final assets = switch (state) {
      AssetsLoaded(:final assets) => assets,
      AssetsActionError(:final assets) => assets,
      _ => <AssetEntity>[],
    };

    if (assets.isEmpty) {
      return RefreshIndicator(
        onRefresh: pullRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.35,
              child: Center(child: Text(l10n.noAssets)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: pullRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
        itemCount: assets.length,
        itemBuilder: (context, index) =>
            _AssetTile(asset: assets[index]),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  final AssetEntity asset;
  const _AssetTile({required this.asset});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<AssetsCubit>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tabular = const [FontFeature.tabularFigures()];

    TextStyle? muted([double? alpha]) =>
        theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: alpha ?? 1),
          height: 1.28,
          fontFeatures: tabular,
        );

    final valueStr =
        l10n.transactionAmountValue(asset.value.toStringAsFixed(2));
    final perApproxMo = assetValuePerApproximateCalendarMonth(
      asset.value,
      asset.boughtAt,
      asset.endedAt,
    );
    final soldPerApproxMo = asset.soldValue != null
        ? assetValuePerApproximateCalendarMonth(
            asset.soldValue!,
            asset.boughtAt,
            asset.endedAt,
          )
        : null;
    final held = formatAssetHoldingDurationYmd(asset.boughtAt, asset.endedAt);
    final heldLabel = l10n.assetHeldDuration(held);

    final locale = Localizations.localeOf(context).toString();
    final dateFmt = DateFormat.yMd(locale);
    String dateLine(DateTime t) => dateFmt.format(t.toLocal());

    final period = asset.endedAt != null
        ? '${dateLine(asset.boughtAt)} → ${dateLine(asset.endedAt!)}'
        : dateLine(asset.boughtAt);

    final titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: -0.25,
      height: 1.25,
    );
    final amountStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.2,
      fontFeatures: tabular,
    );
    final subAmountStyle = muted(0.95)?.copyWith(
      fontWeight: FontWeight.w500,
      fontSize:
          ((muted(null)?.fontSize ?? 13) + 0.25).clamp(12.5, 14.5),
      height: 1.22,
    );

    Widget amountColumn() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(valueStr, style: amountStyle?.copyWith(color: scheme.onSurface)),
          if (perApproxMo != null) ...[
            const SizedBox(height: 3),
            Text(
              l10n.assetValuePerApproximateMonth(
                l10n.transactionAmountValue(
                  perApproxMo.toStringAsFixed(2),
                ),
              ),
              style: subAmountStyle,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (asset.soldValue != null) ...[
            const SizedBox(height: 9),
            Text(
              '${l10n.assetSold}: '
              '${l10n.transactionAmountValue(
                asset.soldValue!.toStringAsFixed(2),
              )}',
              style: subAmountStyle?.copyWith(color: scheme.tertiary),
              textAlign: TextAlign.right,
            ),
            if (soldPerApproxMo != null) ...[
              const SizedBox(height: 2),
              Text(
                l10n.assetSoldPerApproximateMonth(
                  l10n.transactionAmountValue(
                    soldPerApproxMo.toStringAsFixed(2),
                  ),
                ),
                style: subAmountStyle,
                textAlign: TextAlign.right,
                maxLines: 2,
              ),
            ],
          ],
        ],
      );
    }

    Widget metaLine() => Text.rich(
      TextSpan(
        style: muted(0.88),
        children: [
          TextSpan(text: heldLabel),
          TextSpan(text: ' · ', style: muted(0.55)),
          TextSpan(text: period),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );

    void openEdit() {
      showAssetEditorBottomSheet(
        context,
        l10n,
        cubit: cubit,
        asset: asset,
      );
    }

    final provider = asset.provider.trim();
    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Amounts live in [subtitle], not beside [title] inside ListTile — the
        // title row constrains its children to ~kMinInteractiveDimension tall.
        Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 168),
            child: amountColumn(),
          ),
        ),
        if (provider.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(provider, style: muted(0.92), maxLines: 2),
        ],
        const SizedBox(height: 6),
        metaLine(),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SwipeableListTile(
        itemKey: asset.id,
        tileIsThreeLine: true,
        title: Text(
          asset.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        subtitle: subtitle,
        onEdit: openEdit,
        confirmDelete: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.deleteAsset),
              content: Text(l10n.confirmDeleteAsset(asset.name)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.cancel),
                ),
                ElevatedButton(
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    l10n.delete,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
          return ok ?? false;
        },
        onDelete: () => cubit.delete(id: asset.id),
      ),
    );
  }
}
