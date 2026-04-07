-- ================================================================
-- PHASE 1, SCHRITT 1: ALTE TABELLEN DROPPEN
-- ================================================================
-- NUR ausführen NACHDEM das Backup (000) erfolgreich war!
-- Droppt alle alten Tabellen (NICHT die Backups).
-- ================================================================

DO $$
DECLARE
  tbl RECORD;
BEGIN
  -- Alle User-Tabellen im public Schema droppen (außer Backups)
  FOR tbl IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename NOT LIKE 'backup_%'
  LOOP
    EXECUTE format('DROP TABLE IF EXISTS %I CASCADE', tbl.tablename);
    RAISE NOTICE 'Dropped: %', tbl.tablename;
  END LOOP;

  RAISE NOTICE '========================================';
  RAISE NOTICE 'Alle alten Tabellen gelöscht.';
  RAISE NOTICE '========================================';
END;
$$;

-- Auch alte Funktionen droppen die Konflikte verursachen könnten
DROP FUNCTION IF EXISTS get_my_workspace_ids() CASCADE;
DROP FUNCTION IF EXISTS has_workspace_role(UUID, TEXT[]) CASCADE;
DROP FUNCTION IF EXISTS is_superadmin() CASCADE;
DROP FUNCTION IF EXISTS get_agency_company_ids(UUID) CASCADE;
DROP FUNCTION IF EXISTS handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS get_team_mood_avg(UUID, INTEGER) CASCADE;
