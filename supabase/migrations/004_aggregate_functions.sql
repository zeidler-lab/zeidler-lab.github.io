-- ================================================================
-- SCHRITT 20: AGGREGAT-FUNKTION FÜR TEAM-STIMMUNG (DSGVO-sicher)
-- Manager sehen nur den Durchschnitt, nie individuelle Werte
-- ================================================================

CREATE OR REPLACE FUNCTION get_team_mood_avg(
  p_workspace_id UUID,
  p_days INTEGER DEFAULT 7
)
RETURNS TABLE (
  avg_energy      NUMERIC,
  avg_satisfaction NUMERIC,
  avg_motivation  NUMERIC,
  common_help_topics TEXT[],
  response_count  INTEGER
)
LANGUAGE PLPGSQL SECURITY DEFINER AS $$
BEGIN
  -- Prüfen ob Aufrufer Zugang zu diesem Workspace hat
  IF NOT (
    has_workspace_role(p_workspace_id, ARRAY[
      'agency_owner','agency_trainer','agency_manager',
      'company_owner','company_manager'
    ])
    OR is_superadmin()
  ) THEN
    RAISE EXCEPTION 'Unauthorized';
  END IF;

  RETURN QUERY
  SELECT
    ROUND(AVG(dm.energy), 1),
    ROUND(AVG(dm.satisfaction), 1),
    ROUND(AVG(dm.motivation), 1),
    ARRAY_AGG(DISTINCT dm.help_text) FILTER (WHERE dm.help_text IS NOT NULL),
    COUNT(*)::INTEGER
  FROM daily_moods dm
  WHERE dm.user_id IN (
    SELECT ra.user_id FROM rep_assignments ra
    WHERE ra.company_workspace_id = p_workspace_id
    AND ra.is_active = TRUE
  )
  AND dm.date >= CURRENT_DATE - p_days;
END;
$$;
