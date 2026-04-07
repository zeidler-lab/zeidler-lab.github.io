-- ================================================================
-- VERIFIZIERUNG: Prüfe ob alles korrekt eingerichtet wurde
-- ================================================================

-- 1. Alle Tabellen auflisten
SELECT '--- TABELLEN ---' AS info;
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
AND tablename NOT LIKE 'backup_%'
ORDER BY tablename;

-- 2. RLS-Status prüfen (alle sollten TRUE sein)
SELECT '--- RLS STATUS ---' AS info;
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename NOT LIKE 'backup_%'
ORDER BY tablename;

-- 3. Policies zählen
SELECT '--- POLICIES PRO TABELLE ---' AS info;
SELECT schemaname, tablename, COUNT(*) as policy_count
FROM pg_policies
WHERE schemaname = 'public'
GROUP BY schemaname, tablename
ORDER BY tablename;

-- 4. Funktionen prüfen
SELECT '--- HELPER FUNKTIONEN ---' AS info;
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
  'get_my_workspace_ids',
  'has_workspace_role',
  'is_superadmin',
  'get_agency_company_ids',
  'handle_new_user',
  'get_team_mood_avg'
)
ORDER BY routine_name;

-- 5. Trigger prüfen
SELECT '--- TRIGGER ---' AS info;
SELECT trigger_name, event_object_table, action_timing, event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'public' OR event_object_schema = 'auth';

-- 6. Superadmin prüfen
SELECT '--- SUPERADMINS ---' AS info;
SELECT id, email, name, is_superadmin, created_at
FROM profiles
WHERE is_superadmin = TRUE;

-- 7. Backup-Tabellen auflisten
SELECT '--- BACKUPS ---' AS info;
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
AND tablename LIKE 'backup_%'
ORDER BY tablename;
