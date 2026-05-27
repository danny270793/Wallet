import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

import type { GetMonthBalance } from "../../application/GetMonthBalance.js";

export function registerMonthBalanceTools(
  server: McpServer,
  getMonthBalance: GetMonthBalance,
): void {
  server.registerTool(
    "get_month_balance",
    {
      description:
        "Get the user's weighted income, outcome, and balance for a calendar month. " +
        "Mirrors the Flutter transactions page bottom bar (default \"weighted\" mode): " +
        "for every non-deleted, non-transfer-leg transaction, weighted = value * percentage / 100; " +
        "income = sum of positive weighted values, outcome = sum of |negative weighted values|, balance = sum of weighted values. " +
        "Year and month default to the current local month.",
      inputSchema: {
        year: z
          .number()
          .int()
          .min(1970)
          .max(9999)
          .optional()
          .describe("Calendar year (e.g. 2026). Defaults to the current local year."),
        month: z
          .number()
          .int()
          .min(1)
          .max(12)
          .optional()
          .describe("Calendar month, 1-12. Defaults to the current local month."),
      },
    },
    async ({ year, month }) => {
      const input: { year?: number; month?: number } = {};
      if (year !== undefined) input.year = year;
      if (month !== undefined) input.month = month;
      const result = await getMonthBalance.execute(input);
      return {
        content: [{ type: "text", text: JSON.stringify(result) }],
      };
    },
  );
}
