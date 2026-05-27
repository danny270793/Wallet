import type { SupabaseClient } from "@supabase/supabase-js";
import type { MonthBalance } from "../../domain/month-balance/MonthBalance.js";
import type {
  MonthBalanceQuery,
  MonthBalanceRepository,
} from "../../domain/month-balance/MonthBalanceRepository.js";

interface TransactionRow {
  value: number | string;
  percentage: number | string;
  transferGroupId: string | null;
}

/**
 * Mirrors the Flutter `/transactions` page bottom bar (default "weighted, all rows" mode):
 * fetches the same rows the page fetches via {@link transactions_remote_datasource.dart} —
 * `wallet_transactions` filtered by `deletedAt is null` and `transactedAt` in the month —
 * then aggregates them client-side just like {@link transaction_month_totals.dart}:
 *
 * - Skip account-transfer legs (rows with a non-empty `transferGroupId`).
 * - `weighted = value * percentage / 100`.
 * - `income` sums positive weighted values, `outcome` sums absolute negative weighted values, `balance` is the net sum.
 */
export class SupabaseMonthBalanceRepository implements MonthBalanceRepository {
  constructor(private readonly supabase: SupabaseClient) {}

  async get(query: MonthBalanceQuery): Promise<MonthBalance> {
    const { data, error } = await this.supabase
      .from("wallet_transactions")
      .select("value, percentage, transferGroupId")
      .is("deletedAt", null)
      .gte("transactedAt", query.startUtc)
      .lt("transactedAt", query.endUtc);
    if (error) {
      throw new Error(
        `Supabase select wallet_transactions failed: ${error.message}`,
      );
    }
    const rows = (data ?? []) as TransactionRow[];
    let income = 0;
    let outcome = 0;
    let balance = 0;
    for (const row of rows) {
      if (row.transferGroupId !== null && row.transferGroupId !== "") continue;
      const value = Number(row.value);
      const percentage = Number(row.percentage);
      if (!Number.isFinite(value) || !Number.isFinite(percentage)) continue;
      const weighted = (value * percentage) / 100;
      balance += weighted;
      if (weighted > 0) income += weighted;
      else if (weighted < 0) outcome += -weighted;
    }
    return {
      year: query.year,
      month: query.month,
      income,
      outcome,
      balance,
    };
  }
}
