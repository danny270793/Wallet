import type { MonthBalance } from "../domain/month-balance/MonthBalance.js";
import type { MonthBalanceRepository } from "../domain/month-balance/MonthBalanceRepository.js";

export interface GetMonthBalanceInput {
  year?: number;
  month?: number;
}

export class GetMonthBalance {
  constructor(private readonly repo: MonthBalanceRepository) {}

  async execute(input: GetMonthBalanceInput = {}): Promise<MonthBalance> {
    const now = new Date();
    const year = input.year ?? now.getFullYear();
    const month = input.month ?? now.getMonth() + 1;
    if (!Number.isInteger(year) || year < 1970 || year > 9999) {
      throw new Error(`Invalid year: ${year}`);
    }
    if (!Number.isInteger(month) || month < 1 || month > 12) {
      throw new Error(`Invalid month: ${month}`);
    }
    // Mirror Flutter's getTransactionsForMonth: local-time month bounds, then UTC.
    const start = new Date(year, month - 1, 1);
    const end = new Date(year, month, 1);
    return this.repo.get({
      year,
      month,
      startUtc: start.toISOString(),
      endUtc: end.toISOString(),
    });
  }
}
