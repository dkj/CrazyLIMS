# Database SQL Tests

The regression suite runs every `*.sql` file in this directory in lexicographic
order. Each file focuses on a specific slice of behaviour:

- `00_harness.sql` – session-scoped assertion helpers and schema sanity checks.
- `10_security_transaction_context.sql` – admin transaction context and fixture
  setup used by later scenarios.
- `20_security_rls.sql` – row-level security coverage for the different personae
  plus related security views.
- `30_provenance_workflows.sql` – provenance workflow helper regressions.
- `40_labware_views.sql` – convenience views for plate and tube contents.
- `50_handover_workflows.sql` – provenance handover and collaborative transfer
  lifecycles.

New suites can copy the lightweight harness from `00_harness.sql` so they remain
runnable on stock PostgreSQL without external extensions.
