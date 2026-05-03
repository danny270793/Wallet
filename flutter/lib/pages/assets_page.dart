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
import '../widgets/remote_load_failure_panel.dart';
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

    return BlocListener<AssetsCubit, AssetsState>(
      listenWhen: (prev, curr) =>
          curr is AssetsError && prev is! AssetsError,
      listener: (context, state) {
        final s = state as AssetsError;
        showRemoteLoadFailureAlert(
          context,
          l10n,
          s.failure,
          () => context.read<AssetsCubit>().load(showLoading: true),
        );
      },
      child: BlocConsumer<AssetsCubit, AssetsState>(
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
    ),
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
      return RemoteLoadFailurePanel(
        l10n: l10n,
        failure: state.failure,
        onRetry: reloadWithOverlay,
        listPadding: const EdgeInsets.fromLTRB(24, 24, 24, 24 + 88),
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
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 88),
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
    final ymd = assetHoldingCalendarYmd(asset.boughtAt, asset.endedAt);
    final heldLessThanOneFullCalendarMonth =
        ymd != null && ymd.years == 0 && ymd.months == 0;
    final perApproxMo = heldLessThanOneFullCalendarMonth
        ? null
        : assetValuePerApproximateCalendarMonth(
            asset.value,
            asset.boughtAt,
            asset.endedAt,
          );
    final held = formatAssetHoldingDurationYmOmitDaysWhenGrouped(
      asset.boughtAt,
      asset.endedAt,
    );
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
    final trailingMoAsTitle = theme.textTheme.titleMedium?.copyWith(
      color: scheme.primary,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.2,
      fontFeatures: tabular,
    );
    final trailingTotalAsSubtitle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant.withValues(alpha: 0.95),
      fontWeight: FontWeight.w400,
      height: 1.35,
      fontFeatures: tabular,
    );

    Widget purchaseTrailing() {
      if (heldLessThanOneFullCalendarMonth) {
        return Text(
          valueStr,
          style: trailingMoAsTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (perApproxMo != null) ...[
            Text(
              l10n.transactionAmountValue(
                perApproxMo.toStringAsFixed(2),
              ),
              style: trailingMoAsTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 2),
          ],
          Text(
            valueStr,
            style: trailingTotalAsSubtitle,
            textAlign: TextAlign.right,
          ),
        ],
      );
    }

    Widget metaLine() => Text(
      period,
      style: muted(0.88),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );

    final leadingHeld = Padding(
      padding: const EdgeInsets.only(right: 2),
      child: SizedBox(
        width: 52,
        child: Align(
          alignment: Alignment.center,
          child: Text(
            held,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              height: 1.15,
              fontFeatures: tabular,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
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
    final hasSold = asset.soldValue != null;

    final subtitle = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (provider.isNotEmpty) ...[
          Text(provider, style: muted(0.92), maxLines: 2),
          const SizedBox(height: 6),
        ],
        metaLine(),
        if (hasSold) ...[
          const SizedBox(height: 6),
          Text(
            '${l10n.assetSold}: '
            '${l10n.transactionAmountValue(
              asset.soldValue!.toStringAsFixed(2),
            )}',
            style: muted(0.92),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    return SwipeableListTile(
      itemKey: asset.id,
      tileIsThreeLine: true,
      dense: true,
      minLeadingWidth: 54,
      horizontalTitleGap: 8,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: leadingHeld,
      title: Text(
        asset.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: titleStyle,
      ),
      subtitle: subtitle,
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 72, maxWidth: 152),
        child: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: purchaseTrailing(),
        ),
      ),
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
    );
  }
}
