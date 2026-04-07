# SNASH HUB — Datenbank Setup

## Supabase-Projekt
- **URL:** `https://qzrrgnwsehrfguxzudxw.supabase.co`
- **Dashboard:** `https://supabase.com/dashboard/project/qzrrgnwsehrfguxzudxw`

## Phase 1: Datenbankfundament einrichten

Alle SQL-Dateien im Supabase SQL Editor ausführen — **in dieser Reihenfolge:**

### Schritt 1: Backup
```
migrations/000_backup_existing_tables.sql
```
Erstellt Kopien aller bestehenden Tabellen mit `backup_`-Prefix.
**Prüfe die Ausgabe** — es sollte "Backup abgeschlossen!" erscheinen.

### Schritt 2: Alte Tabellen droppen
```
migrations/001_drop_old_tables.sql
```
Löscht alle alten Tabellen (Backups bleiben erhalten).

### Schritt 3: Neues Schema erstellen (Schritte 1-18)
```
migrations/002_create_schema.sql
```
Erstellt alle 17 Tabellen + Helper-Funktionen + Indizes.

### Schritt 4: RLS & Policies aktivieren (Schritt 19)
```
migrations/003_enable_rls_and_policies.sql
```
Aktiviert Row Level Security auf allen Tabellen + alle Policies.

### Schritt 5: Aggregat-Funktionen (Schritt 20)
```
migrations/004_aggregate_functions.sql
```
DSGVO-sichere Team-Mood-Aggregation.

### Schritt 6: Superadmin setzen
```
migrations/005_set_superadmin.sql
```
Setzt `kevin@zeidler.media` als Superadmin.

## Verifizierung

Nach Ausführung aller Skripte im SQL Editor prüfen:

```sql
-- Alle neuen Tabellen anzeigen
SELECT tablename FROM pg_tables
WHERE schemaname = 'public'
AND tablename NOT LIKE 'backup_%'
ORDER BY tablename;

-- Superadmin prüfen
SELECT id, email, name, is_superadmin FROM profiles
WHERE is_superadmin = TRUE;

-- RLS-Status prüfen
SELECT tablename, rowsecurity FROM pg_tables
WHERE schemaname = 'public'
AND tablename NOT LIKE 'backup_%'
ORDER BY tablename;
```

## Erwartete Tabellen (17 Stück)

| # | Tabelle | Zweck |
|---|---------|-------|
| 1 | `workspaces` | Agencies & Companies |
| 2 | `profiles` | User-Profile |
| 3 | `workspace_members` | Wer gehört wozu mit welcher Rolle |
| 4 | `rep_assignments` | Vertriebler-Zuordnungen |
| 5 | `mentees` | Mentee-Zuordnungen |
| 6 | `agency_company_links` | Agency betreut Company |
| 7 | `tracking_entries` | Tägliche Zahlen |
| 8 | `daily_moods` | Stimmungstracking |
| 9 | `rep_points` | Punktesystem |
| 10 | `zoom_accounts` | Zoom-Verbindungen |
| 11 | `trainings` | Training-Sessions |
| 12 | `training_attendance` | Teilnahme |
| 13 | `prizes` | Monatsgewinn |
| 14 | `inbox_messages` | Postfach |
| 15 | `trainer_feedback` | Trainer-Feedback |
| 16 | `job_postings` | Stellenmarkt |
| 17 | `job_applications` | Bewerbungen |
| 18 | `admin_impersonation_log` | Sicherheitslog |
