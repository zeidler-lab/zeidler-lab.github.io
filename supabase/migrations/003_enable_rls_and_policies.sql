-- ================================================================
-- SCHRITT 19: ROW LEVEL SECURITY — VOLLSTÄNDIG
-- ================================================================

-- Alle Tabellen mit RLS schützen
ALTER TABLE workspaces           ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles             ENABLE ROW LEVEL SECURITY;
ALTER TABLE workspace_members    ENABLE ROW LEVEL SECURITY;
ALTER TABLE rep_assignments      ENABLE ROW LEVEL SECURITY;
ALTER TABLE mentees              ENABLE ROW LEVEL SECURITY;
ALTER TABLE agency_company_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE tracking_entries     ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_moods          ENABLE ROW LEVEL SECURITY;
ALTER TABLE rep_points           ENABLE ROW LEVEL SECURITY;
ALTER TABLE zoom_accounts        ENABLE ROW LEVEL SECURITY;
ALTER TABLE trainings            ENABLE ROW LEVEL SECURITY;
ALTER TABLE training_attendance  ENABLE ROW LEVEL SECURITY;
ALTER TABLE prizes               ENABLE ROW LEVEL SECURITY;
ALTER TABLE inbox_messages       ENABLE ROW LEVEL SECURITY;
ALTER TABLE trainer_feedback     ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_postings         ENABLE ROW LEVEL SECURITY;
ALTER TABLE job_applications     ENABLE ROW LEVEL SECURITY;

-- ─── PROFILES ───────────────────────────────────────────────────
CREATE POLICY "profiles_own_all" ON profiles
  FOR ALL USING (auth.uid() = id);

CREATE POLICY "profiles_superadmin" ON profiles
  FOR SELECT USING (is_superadmin());

CREATE POLICY "profiles_workspace_colleagues" ON profiles
  FOR SELECT USING (
    id IN (
      SELECT wm.user_id FROM workspace_members wm
      WHERE wm.workspace_id IN (SELECT get_my_workspace_ids())
      AND wm.joined_at IS NOT NULL
    )
    OR
    id IN (
      SELECT ra.user_id FROM rep_assignments ra
      WHERE ra.company_workspace_id IN (SELECT get_my_workspace_ids())
    )
  );

-- ─── WORKSPACES ──────────────────────────────────────────────────
CREATE POLICY "workspaces_members" ON workspaces
  FOR SELECT USING (
    id IN (SELECT get_my_workspace_ids())
    OR is_superadmin()
  );

CREATE POLICY "workspaces_superadmin_insert" ON workspaces
  FOR INSERT WITH CHECK (is_superadmin());

CREATE POLICY "workspaces_owner_update" ON workspaces
  FOR UPDATE USING (
    is_superadmin()
    OR has_workspace_role(id, ARRAY['agency_owner','company_owner'])
  );

-- ─── WORKSPACE_MEMBERS ───────────────────────────────────────────
CREATE POLICY "wm_own" ON workspace_members
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "wm_workspace_admins" ON workspace_members
  FOR SELECT USING (
    workspace_id IN (SELECT get_my_workspace_ids())
    AND has_workspace_role(workspace_id, ARRAY[
      'agency_owner','agency_trainer','agency_manager',
      'company_owner','company_manager'
    ])
    OR is_superadmin()
  );

CREATE POLICY "wm_invite" ON workspace_members
  FOR INSERT WITH CHECK (
    has_workspace_role(workspace_id, ARRAY['agency_owner','company_owner'])
    OR is_superadmin()
  );

CREATE POLICY "wm_remove" ON workspace_members
  FOR DELETE USING (
    has_workspace_role(workspace_id, ARRAY['agency_owner','company_owner'])
    OR is_superadmin()
    OR user_id = auth.uid()
  );

-- ─── REP_ASSIGNMENTS ─────────────────────────────────────────────
CREATE POLICY "ra_own" ON rep_assignments
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "ra_company_managers" ON rep_assignments
  FOR SELECT USING (
    company_workspace_id IN (SELECT get_my_workspace_ids())
    OR is_superadmin()
  );

CREATE POLICY "ra_agency_view" ON rep_assignments
  FOR SELECT USING (
    company_workspace_id IN (
      SELECT company_workspace_id FROM agency_company_links
      WHERE agency_workspace_id IN (SELECT get_my_workspace_ids())
    )
    OR is_superadmin()
  );

CREATE POLICY "ra_insert" ON rep_assignments
  FOR INSERT WITH CHECK (
    has_workspace_role(company_workspace_id, ARRAY['company_owner','company_manager'])
    OR
    company_workspace_id IN (
      SELECT company_workspace_id FROM agency_company_links
      WHERE agency_workspace_id IN (
        SELECT workspace_id FROM workspace_members
        WHERE user_id = auth.uid()
        AND role IN ('agency_owner','agency_manager')
        AND joined_at IS NOT NULL
      )
    )
    OR is_superadmin()
  );

CREATE POLICY "ra_update" ON rep_assignments
  FOR UPDATE USING (
    has_workspace_role(company_workspace_id, ARRAY['company_owner','company_manager'])
    OR is_superadmin()
  );

-- ─── MENTEES ─────────────────────────────────────────────────────
CREATE POLICY "mentees_own" ON mentees
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "mentees_agency" ON mentees
  FOR SELECT USING (
    agency_workspace_id IN (SELECT get_my_workspace_ids())
    OR is_superadmin()
  );

CREATE POLICY "mentees_insert" ON mentees
  FOR INSERT WITH CHECK (
    has_workspace_role(agency_workspace_id, ARRAY['agency_owner','agency_trainer'])
    OR is_superadmin()
  );

-- ─── TRACKING_ENTRIES ────────────────────────────────────────────
CREATE POLICY "te_own" ON tracking_entries
  FOR ALL USING (user_id = auth.uid());

CREATE POLICY "te_company_managers" ON tracking_entries
  FOR SELECT USING (
    company_workspace_id IN (SELECT get_my_workspace_ids())
    OR is_superadmin()
  );

CREATE POLICY "te_agency" ON tracking_entries
  FOR SELECT USING (
    company_workspace_id IN (
      SELECT company_workspace_id FROM agency_company_links
      WHERE agency_workspace_id IN (SELECT get_my_workspace_ids())
    )
    OR is_superadmin()
  );

-- ─── DAILY_MOODS ─────────────────────────────────────────────────
CREATE POLICY "moods_own" ON daily_moods
  FOR ALL USING (user_id = auth.uid());

-- ─── REP_POINTS ──────────────────────────────────────────────────
CREATE POLICY "points_own" ON rep_points
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "points_team" ON rep_points
  FOR SELECT USING (
    company_workspace_id IN (
      SELECT ra.company_workspace_id FROM rep_assignments ra
      WHERE ra.user_id = auth.uid() AND ra.is_active = TRUE
    )
    OR is_superadmin()
  );

CREATE POLICY "points_insert" ON rep_points
  FOR INSERT WITH CHECK (auth.uid() = user_id OR is_superadmin());

-- ─── ZOOM_ACCOUNTS ───────────────────────────────────────────────
CREATE POLICY "zoom_own" ON zoom_accounts
  FOR ALL USING (user_id = auth.uid());

-- ─── TRAININGS ───────────────────────────────────────────────────
CREATE POLICY "trainings_members" ON trainings
  FOR SELECT USING (
    workspace_id IN (SELECT get_my_workspace_ids())
    OR
    workspace_id IN (
      SELECT agency_workspace_id FROM mentees
      WHERE user_id = auth.uid() AND status = 'active'
    )
    OR
    workspace_id IN (
      SELECT acl.agency_workspace_id FROM agency_company_links acl
      JOIN rep_assignments ra ON ra.company_workspace_id = acl.company_workspace_id
      WHERE ra.user_id = auth.uid() AND ra.is_active = TRUE
    )
    OR is_superadmin()
  );

CREATE POLICY "trainings_insert" ON trainings
  FOR INSERT WITH CHECK (
    has_workspace_role(workspace_id, ARRAY[
      'agency_owner','agency_trainer',
      'company_owner','company_manager','company_trainer'
    ])
    OR is_superadmin()
  );

-- ─── TRAINING_ATTENDANCE ─────────────────────────────────────────
CREATE POLICY "attendance_own" ON training_attendance
  FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "attendance_trainer" ON training_attendance
  FOR SELECT USING (
    training_id IN (
      SELECT id FROM trainings WHERE workspace_id IN (SELECT get_my_workspace_ids())
    )
    OR is_superadmin()
  );

CREATE POLICY "attendance_update" ON training_attendance
  FOR ALL USING (
    training_id IN (
      SELECT id FROM trainings WHERE workspace_id IN (SELECT get_my_workspace_ids())
    )
    OR is_superadmin()
  );

-- ─── INBOX ───────────────────────────────────────────────────────
CREATE POLICY "inbox_own" ON inbox_messages
  FOR ALL USING (recipient_id = auth.uid());

-- ─── JOB POSTINGS ────────────────────────────────────────────────
CREATE POLICY "jobs_public_read" ON job_postings
  FOR SELECT USING (active = TRUE);

CREATE POLICY "jobs_insert" ON job_postings
  FOR INSERT WITH CHECK (
    has_workspace_role(workspace_id, ARRAY['agency_owner','company_owner','company_manager'])
    OR is_superadmin()
  );

-- ─── JOB_APPLICATIONS ────────────────────────────────────────────
CREATE POLICY "applications_own" ON job_applications
  FOR ALL USING (applicant_id = auth.uid());

CREATE POLICY "applications_employer" ON job_applications
  FOR SELECT USING (
    job_posting_id IN (
      SELECT id FROM job_postings WHERE workspace_id IN (SELECT get_my_workspace_ids())
    )
    OR is_superadmin()
  );

-- ─── TRAINER_FEEDBACK ────────────────────────────────────────────
CREATE POLICY "feedback_own" ON trainer_feedback
  FOR SELECT USING (
    recipient_id = auth.uid()
    OR trainer_id = auth.uid()
    OR is_superadmin()
  );

CREATE POLICY "feedback_insert" ON trainer_feedback
  FOR INSERT WITH CHECK (trainer_id = auth.uid() OR is_superadmin());

-- ─── AGENCY_COMPANY_LINKS ────────────────────────────────────────
CREATE POLICY "acl_read" ON agency_company_links
  FOR SELECT USING (
    agency_workspace_id IN (SELECT get_my_workspace_ids())
    OR company_workspace_id IN (SELECT get_my_workspace_ids())
    OR is_superadmin()
  );

CREATE POLICY "acl_insert" ON agency_company_links
  FOR INSERT WITH CHECK (
    has_workspace_role(agency_workspace_id, ARRAY['agency_owner'])
    OR is_superadmin()
  );
