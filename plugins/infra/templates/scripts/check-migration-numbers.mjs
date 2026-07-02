#!/usr/bin/env node
// Fails if any migration file in supabase/migrations/ shares a numeric version
// prefix with another. Duplicate versions are silently skipped by
// `supabase db push` (version is the schema_migrations primary key), which
// causes prod/dev drift.

import { readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const migrationsDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'supabase', 'migrations');

const files = readdirSync(migrationsDir).filter((f) => f.endsWith('.sql'));

const byVersion = new Map();
for (const file of files) {
  const match = file.match(/^(\d+)_/);
  if (!match) {
    console.error(`✗ Migration file without numeric prefix: ${file}`);
    process.exit(1);
  }
  const version = match[1];
  if (!byVersion.has(version)) byVersion.set(version, []);
  byVersion.get(version).push(file);
}

const collisions = [...byVersion.entries()].filter(([, names]) => names.length > 1);

if (collisions.length > 0) {
  console.error('✗ Duplicate migration version prefixes detected:');
  for (const [version, names] of collisions) {
    console.error(`  ${version}: ${names.join(', ')}`);
  }
  console.error('\nEach migration must have a unique numeric version. `supabase db push`');
  console.error('keys on the prefix, so duplicates get silently skipped and cause drift.');
  process.exit(1);
}

console.log(`✓ ${files.length} migrations, all version prefixes unique.`);
