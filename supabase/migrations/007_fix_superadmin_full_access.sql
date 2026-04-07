-- ================================================================
-- FIX: Superadmin bekommt vollen Zugriff auf ALLE Tabellen
-- ================================================================

CREATE POLICY "superadmin_full_workspaces" ON workspaces
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_profiles" ON profiles
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_wm" ON workspace_members
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_ra" ON rep_assignments
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_mentees" ON mentees
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_acl" ON agency_company_links
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_te" ON tracking_entries
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_moods" ON daily_moods
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_points" ON rep_points
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_zoom" ON zoom_accounts
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_trainings" ON trainings
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_attendance" ON training_attendance
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_prizes" ON prizes
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_inbox" ON inbox_messages
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_feedback" ON trainer_feedback
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_jobs" ON job_postings
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

CREATE POLICY "superadmin_full_applications" ON job_applications
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());

ALTER TABLE admin_impersonation_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "superadmin_full_impersonation" ON admin_impersonation_log
  FOR ALL USING (is_superadmin()) WITH CHECK (is_superadmin());
