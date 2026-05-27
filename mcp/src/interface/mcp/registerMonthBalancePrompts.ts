import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";

export function registerMonthBalancePrompts(server: McpServer): void {
  server.registerPrompt(
    "month-balance",
    {
      title: "Month balance",
      description:
        "Ask the wallet for the weighted income, outcome, and balance of a given month.",
    },
    () => ({
      messages: [
        {
          role: "user",
          content: {
            type: "text",
            text: "What is my weighted income, outcome, and balance for this month? Use the get_month_balance tool and report all three values.",
          },
        },
      ],
    }),
  );
}
