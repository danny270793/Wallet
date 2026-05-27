import "dotenv/config";

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required env var: ${name}`);
  }
  return value;
}

export const env = {
  supabaseUrl: required("SUPABASE_URL"),
  supabaseAnonKey: required("SUPABASE_ANON_KEY"),
  supabaseUserEmail: required("SUPABASE_USER_EMAIL"),
  supabaseUserPassword: required("SUPABASE_USER_PASSWORD"),
};
