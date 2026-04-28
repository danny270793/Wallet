# Flutter Environment Variables

In Flutter, `String.fromEnvironment` values are compiled into the binary at build time — there are no runtime environment variables. You supply them via `--dart-define` or `--dart-define-from-file` during the build.

## Local development

Create a `.env.json` file at the project root (already in `.gitignore`):

```json
{
  "SUPABASE_URL": "https://<project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<your-anon-key>"
}
```

Then run or build with:

```sh
flutter run --dart-define-from-file=.env.json
flutter build apk --dart-define-from-file=.env.json
flutter build ipa --dart-define-from-file=.env.json
```

## CI/CD (GitHub Actions)

Store the values as repository secrets, then pass them in the workflow:

```yaml
- name: Build APK
  run: |
    flutter build apk \
      --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }} \
      --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
```

## About the Supabase anon key

The anon key is **intentionally public** — it is a JWT that identifies your project and will always be visible in compiled client code. Supabase uses **Row Level Security (RLS)** on the database to protect data, not the key itself.

Keep it out of version control, but do not treat it as a password.

The **service role key** bypasses RLS entirely and must never be used in client-side code.
