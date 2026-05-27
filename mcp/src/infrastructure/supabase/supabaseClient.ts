import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { env } from "../config/env.js";

/**
 * Creates a Supabase client and signs in as the configured user so RLS-scoped
 * tables (e.g. `wallet_transactions`) return that user's rows. Without this
 * sign-in, queries run as the anon role and RLS filters them to nothing.
 *
 * `persistSession: false` keeps the session in memory only (no disk writes
 * from a stdio MCP process); `autoRefreshToken` stays at its default `true`
 * so the access token refreshes for as long as the server is running.
 */
export async function createSupabaseClient(): Promise<SupabaseClient> {
  const client = createClient(env.supabaseUrl, env.supabaseAnonKey, {
    auth: { persistSession: false },
  });
  const { error } = await client.auth.signInWithPassword({
    email: env.supabaseUserEmail,
    password: env.supabaseUserPassword,
  });
  if (error) {
    throw new Error(`Supabase sign-in failed: ${error.message}`);
  }
  return client;
}
