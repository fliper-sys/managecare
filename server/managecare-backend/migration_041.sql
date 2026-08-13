-- The Firestore->Postgres migration tooling has, at different times, stored
-- sales.legacy_firestore_id as either the bare Firestore doc id ("abc123")
-- or the full path ("bus_X/sales/abc123"). The existing unique index on
-- (business_id, legacy_firestore_id) only catches exact string matches, so
-- the same original sale imported under both conventions produced two rows
-- with different primary keys and slipped past ON CONFLICT (id) entirely -
-- 16,642 duplicate rows across 30 businesses. This index keys off the
-- canonical Firestore doc id (the path's final segment, which is the bare
-- id already for the short form) so any future import collides regardless
-- of which path convention it uses.
-- 8 businesses still carry unresolved pairs where the two duplicate rows
-- disagree on total_amount (can't tell which figure is correct without
-- owner/source-of-truth review), so they're excluded here until resolved -
-- see docs/sales_ambiguous_duplicates.csv for the list to review.
CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_business_legacy_fs_canonical
  ON sales (business_id, (regexp_replace(legacy_firestore_id, '^.*/', '')))
  WHERE legacy_firestore_id IS NOT NULL
    AND business_id NOT IN (
      '4ff8dc0c-1d3e-5a06-b8cb-188559bf3368',
      'da3e124b-0704-590a-a69d-76da96a07f42',
      '42a44315-ee2d-588a-92c2-3c8a2e902d9c',
      'd6e093b6-7c3f-5756-94d5-7c8afea88618',
      '1585565f-6bdf-596a-884a-763ed136327f',
      'aa2f33c7-80b2-5b53-9500-d57512cd29fd',
      'c122cb73-de56-51ac-8de0-3f394c2a0529',
      '8418286a-25c9-5fe3-9494-905d75c4ef9c'
    );
