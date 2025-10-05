# Development JWT Fixtures

These example tokens let you impersonate common personas when calling PostgREST or PostGraphile in the dev stack. They are signed with the same secret defined in `docker-compose.yml` (`dev_jwt_secret_change_me_which_is_at_least_32_characters`).

## Files

- `admin.jwt` – Administrator with operator fallback role.
- `operator.jwt` – Operations user able to manage samples.
- `researcher.jwt` – Researcher (Alice) with read access scoped to her samples.
- `researcher_bob.jwt` – Researcher (Bob) scoped to a different project/sample set.

## Regenerating tokens

Run the helper script to regenerate all dev fixtures after changing claims or the signing secret:

```bash
make jwt/dev
```

Tokens are long-lived for convenience (`exp` set far in the future). For production you should issue short-lived tokens from your identity provider instead of checking these into git.
