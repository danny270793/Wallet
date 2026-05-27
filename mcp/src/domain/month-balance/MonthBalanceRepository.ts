import type { MonthBalance } from "./MonthBalance.js";

export interface MonthBalanceQuery {
  year: number;
  month: number;
  startUtc: string;
  endUtc: string;
}

export interface MonthBalanceRepository {
  get(query: MonthBalanceQuery): Promise<MonthBalance>;
}
