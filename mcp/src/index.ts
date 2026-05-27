import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";

import { GetMonthBalance } from "./application/GetMonthBalance.js";
import { SupabaseMonthBalanceRepository } from "./infrastructure/supabase/SupabaseMonthBalanceRepository.js";
import { createSupabaseClient } from "./infrastructure/supabase/supabaseClient.js";
import { registerMonthBalancePrompts } from "./interface/mcp/registerMonthBalancePrompts.js";
import { registerMonthBalanceTools } from "./interface/mcp/registerMonthBalanceTools.js";

const supabase = await createSupabaseClient();
const monthBalanceRepository = new SupabaseMonthBalanceRepository(supabase);
const getMonthBalance = new GetMonthBalance(monthBalanceRepository);

const server = new McpServer({ name: "wallet", version: "0.0.1" });

registerMonthBalanceTools(server, getMonthBalance);
registerMonthBalancePrompts(server);

await server.connect(new StdioServerTransport());
