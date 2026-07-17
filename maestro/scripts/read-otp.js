#!/usr/bin/env node
// CI-only helper: reads a pending registration's OTP directly out of the
// test backend's SQLite file, exactly like the backend's own Playwright
// suite does (sallehly/tests/*.spec.js's getPendingOtp helper) — there's no
// email inbox to check in CI, so this is how a seed account gets past the
// real OTP-verification step instead of the app being modified to bypass it.
//
// Usage: node read-otp.js <path-to-better-sqlite3-module-dir> <db-path> <email>
// Prints the 6-digit OTP to stdout on success, exits 1 with a message on
// stderr if no pending registration is found for that email.

const [, , betterSqlite3Path, dbPath, email] = process.argv;

if (!betterSqlite3Path || !dbPath || !email) {
  console.error('Usage: node read-otp.js <better-sqlite3-module-dir> <db-path> <email>');
  process.exit(1);
}

const Database = require(betterSqlite3Path);
const db = new Database(dbPath, { readonly: true });

try {
  const row = db
    .prepare('SELECT otp FROM pending_users WHERE email = ? ORDER BY id DESC LIMIT 1')
    .get(email.toLowerCase());

  if (!row) {
    console.error(`No pending_users row found for ${email}`);
    process.exit(1);
  }

  process.stdout.write(row.otp);
} finally {
  db.close();
}
