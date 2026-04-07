-- ================================================================
-- SUPERADMIN SETZEN: kevin@zeidler.media
-- ================================================================
-- Dieser Schritt setzt den is_superadmin Flag für Kevin.
--
-- WICHTIG: Kevin muss sich VORHER mindestens einmal registriert/
-- eingeloggt haben, damit sein Profil in der profiles-Tabelle existiert.
--
-- Falls das Profil noch nicht existiert (User hat sich noch nicht
-- registriert), wird es manuell angelegt.
-- ================================================================

-- Erst prüfen ob der User existiert
DO $$
DECLARE
  kevin_id UUID;
  kevin_exists BOOLEAN;
BEGIN
  -- User-ID aus auth.users holen
  SELECT id INTO kevin_id
  FROM auth.users
  WHERE email = 'kevin@zeidler.media'
  LIMIT 1;

  IF kevin_id IS NULL THEN
    RAISE NOTICE '⚠️  kevin@zeidler.media wurde in auth.users NICHT gefunden.';
    RAISE NOTICE '→  Kevin muss sich zuerst registrieren/einloggen.';
    RAISE NOTICE '→  Danach dieses Skript erneut ausführen.';
  ELSE
    -- Prüfen ob Profil existiert
    SELECT EXISTS(SELECT 1 FROM profiles WHERE id = kevin_id) INTO kevin_exists;

    IF NOT kevin_exists THEN
      -- Profil manuell anlegen
      INSERT INTO profiles (id, email, name, is_superadmin, onboarding_done)
      VALUES (kevin_id, 'kevin@zeidler.media', 'Kevin Zeidler', TRUE, TRUE);
      RAISE NOTICE '✅ Profil für kevin@zeidler.media angelegt + Superadmin gesetzt!';
    ELSE
      -- Profil updaten
      UPDATE profiles
      SET is_superadmin = TRUE, onboarding_done = TRUE, updated_at = NOW()
      WHERE id = kevin_id;
      RAISE NOTICE '✅ kevin@zeidler.media ist jetzt Superadmin!';
    END IF;

    -- Verifizierung
    RAISE NOTICE 'User-ID: %', kevin_id;
  END IF;
END;
$$;

-- Verifizierung: Alle Superadmins anzeigen
SELECT id, email, name, is_superadmin, onboarding_done, created_at
FROM profiles
WHERE is_superadmin = TRUE;
