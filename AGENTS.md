# Agent guidelines for CrazyLIMS

These instructions apply to the entire repository. Keep this file up to date if expectations change.

## How to work in this repo
- **Check for nested `AGENTS.md` files** when you touch subdirectories; deeper files override this one.
- Prefer the documented workflow in [`docs/overview.md`](docs/overview.md) and the `Makefile` when starting or testing services.
- Write clear comments or docstrings for new code or tests so future contributors can follow the reasoning.
- Do **not** wrap imports in try/catch blocks.

## Tests and validation
- Run tests by default. For full verification before a PR, prefer `make ci` (db reset + migrations + contract export + RBAC/REST/UI smoke tests).
- If you need a faster iteration loop, run targeted suites such as `make test/security`, `make test/rest-story`, or `make test/ui`, and explain any deviations from `make ci` in your summary.
- Always add or update tests when you add or change functionality.

## Change management
- Keep PR/commit messages concise but descriptive; mention key components touched.
- When updating API contracts or migrations, ensure generated artifacts in `contracts/` stay in sync.
- Coordinate documentation updates: prefer placing new high-level guidance in `docs/` and linking it from `README.md` when appropriate.
