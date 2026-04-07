-- ================================================================
-- PHASE 1, SCHRITT 0: BACKUP BESTEHENDER TABELLEN
-- ================================================================
-- Führe dieses Skript ZUERST aus, bevor du die neuen Tabellen erstellst.
-- Es erstellt Kopien aller bestehenden Tabellen mit dem Prefix "backup_".
--
-- WICHTIG: Im Supabase SQL Editor ausführen!
-- ================================================================

DO $$
DECLARE
  tbl RECORD;
  backup_name TEXT;
BEGIN
  -- Alle User-Tabellen im public Schema durchgehen
  FOR tbl IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename NOT LIKE 'backup_%'
  LOOP
    backup_name := 'backup_' || tbl.tablename || '_' || to_char(NOW(), 'YYYYMMDD_HH24MI');

    -- Backup-Tabelle erstellen (Struktur + Daten)
    EXECUTE format(
      'CREATE TABLE IF NOT EXISTS %I AS SELECT * FROM %I',
      backup_name,
      tbl.tablename
    );

    RAISE NOTICE 'Backed up: % -> %', tbl.tablename, backup_name;
  END LOOP;

  -- Zusammenfassung ausgeben
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Backup abgeschlossen!';
  RAISE NOTICE 'Alle Tabellen wurden mit Prefix backup_ kopiert.';
  RAISE NOTICE '========================================';
END;
$$;

-- Verifizierung: Zeige alle Backup-Tabellen
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
AND tablename LIKE 'backup_%'
ORDER BY tablename;
