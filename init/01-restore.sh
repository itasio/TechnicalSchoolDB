#!/bin/bash
set -e

echo "Restoring database from backup..."

pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" /data/db_combined_phases.backup

echo "Restore complete."