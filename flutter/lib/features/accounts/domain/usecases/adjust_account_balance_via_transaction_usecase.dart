import '../../../categories/domain/usecases/create_category_usecase.dart';
import '../../../categories/domain/usecases/get_categories_usecase.dart';
import '../../../tags/domain/usecases/create_tag_usecase.dart';
import '../../../tags/domain/usecases/get_tags_usecase.dart';
import '../../../transactions/domain/usecases/create_transaction_usecase.dart';

/// Ensures category/tag named [adjustmentLabel] exist, then creates a transaction
/// with that label as description, category, and tag so [delta] updates the account balance.
class AdjustAccountBalanceViaTransactionUsecase {
  static const adjustmentLabel = 'Adjustment';

  final GetCategoriesUsecase _getCategories;
  final CreateCategoryUsecase _createCategory;
  final GetTagsUsecase _getTags;
  final CreateTagUsecase _createTag;
  final CreateTransactionUsecase _createTransaction;

  const AdjustAccountBalanceViaTransactionUsecase({
    required GetCategoriesUsecase getCategories,
    required CreateCategoryUsecase createCategory,
    required GetTagsUsecase getTags,
    required CreateTagUsecase createTag,
    required CreateTransactionUsecase createTransaction,
  }) : _getCategories = getCategories,
       _createCategory = createCategory,
       _getTags = getTags,
       _createTag = createTag,
       _createTransaction = createTransaction;

  Future<void> call({required String accountId, required double delta}) async {
    if (delta.abs() < 1e-9) return;

    final categories = (await _getCategories()).value;
    String? categoryId;
    for (final c in categories) {
      if (c.name == adjustmentLabel) {
        categoryId = c.id;
        break;
      }
    }
    categoryId ??= (await _createCategory(name: adjustmentLabel)).id;

    final tags = (await _getTags()).value;
    String? tagId;
    for (final t in tags) {
      if (t.name == adjustmentLabel) {
        tagId = t.id;
        break;
      }
    }
    tagId ??= (await _createTag(name: adjustmentLabel)).id;

    await _createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      tagId: tagId,
      description: adjustmentLabel,
      transactedAt: DateTime.now(),
      value: delta,
      ignore: false,
      percentage: 100,
    );
  }
}
