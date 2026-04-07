-- ================================================================
-- PHASE 1: VOLLSTÄNDIGES DATENBANKSCHEMA — SCHRITTE 1-20
-- ================================================================
-- SNASH HUB User Management Architektur
-- Multi-Tenant mit Workspace-Konzept
-- ================================================================

-- ================================================================
-- SCHRITT 1: HELPER FUNKTIONEN (zuerst — RLS braucht sie)
-- ================================================================

-- Gibt die workspace_ids zurück wo der User Mitglied ist
CREATE OR REPLACE FUNCTION get_my_workspace_ids()
RETURNS SETOF UUID
LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT workspace_id FROM workspace_members
  WHERE user_id = auth.uid() AND joined_at IS NOT NULL;
$$;

-- Prüft ob User in einem Workspace eine bestimmte Rolle hat
CREATE OR REPLACE FUNCTION has_workspace_role(
  p_workspace_id UUID,
  p_roles TEXT[]
)
RETURNS BOOLEAN
LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM workspace_members
    WHERE workspace_id = p_workspace_id
    AND user_id = auth.uid()
    AND role = ANY(p_roles)
    AND joined_at IS NOT NULL
  );
$$;

-- Prüft ob User Superadmin ist
CREATE OR REPLACE FUNCTION is_superadmin()
RETURNS BOOLEAN
LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND is_superadmin = TRUE
  );
$$;

-- Gibt alle Company-Workspace-IDs zurück die eine Agency betreut
CREATE OR REPLACE FUNCTION get_agency_company_ids(p_agency_id UUID)
RETURNS SETOF UUID
LANGUAGE SQL SECURITY DEFINER STABLE AS $$
  SELECT company_workspace_id FROM agency_company_links
  WHERE agency_workspace_id = p_agency_id;
$$;

-- ================================================================
-- SCHRITT 2: WORKSPACES
-- ================================================================

CREATE TABLE workspaces (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type                  TEXT NOT NULL CHECK (type IN ('agency', 'company')),
  name                  TEXT NOT NULL,
  slug                  TEXT UNIQUE NOT NULL,

  -- Branding (White-Label)
  logo_url              TEXT,
  accent_color          TEXT DEFAULT '#00d4ff',
  theme                 TEXT DEFAULT 'cyber' CHECK (theme IN ('cyber','greek','rose')),
  white_label_enabled   BOOLEAN DEFAULT FALSE,

  -- Feature-Flags (vom Admin aktiviert)
  ranking_enabled       BOOLEAN DEFAULT FALSE,
  prize_enabled         BOOLEAN DEFAULT FALSE,
  training_enabled      BOOLEAN DEFAULT FALSE,
  marketplace_enabled   BOOLEAN DEFAULT FALSE,

  -- Billing
  plan                  TEXT DEFAULT 'trial' CHECK (plan IN ('trial','starter','growth','pro')),
  trial_ends_at         TIMESTAMPTZ,
  billing_email         TEXT,

  -- Status
  is_active             BOOLEAN DEFAULT TRUE,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  created_by            UUID REFERENCES auth.users(id)
);

CREATE INDEX idx_workspaces_type ON workspaces(type);
CREATE INDEX idx_workspaces_slug ON workspaces(slug);

-- ================================================================
-- SCHRITT 3: PROFILES (erweitert)
-- ================================================================

CREATE TABLE profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name            TEXT,
  email           TEXT UNIQUE,
  avatar_url      TEXT,

  -- Platform-Level Flag (NUR für Kevin)
  is_superadmin   BOOLEAN DEFAULT FALSE,

  -- Onboarding
  onboarding_done BOOLEAN DEFAULT FALSE,

  -- Streak
  current_streak  INTEGER DEFAULT 0,
  last_entry_date DATE,

  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Automatisch Profile anlegen bei User-Registrierung
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE PLPGSQL SECURITY DEFINER AS $$
BEGIN
  INSERT INTO profiles (id, email, name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1))
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ================================================================
-- SCHRITT 4: WORKSPACE MITGLIEDER (das Herzstück)
-- ================================================================

CREATE TABLE workspace_members (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id  UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  role          TEXT NOT NULL CHECK (role IN (
    'agency_owner', 'agency_trainer', 'agency_manager',
    'company_owner', 'company_manager', 'company_trainer'
  )),

  invited_by    UUID REFERENCES auth.users(id),
  invited_at    TIMESTAMPTZ DEFAULT NOW(),
  joined_at     TIMESTAMPTZ,

  invite_token  TEXT UNIQUE DEFAULT gen_random_uuid()::TEXT,

  UNIQUE(workspace_id, user_id)
);

CREATE INDEX idx_wm_workspace ON workspace_members(workspace_id);
CREATE INDEX idx_wm_user ON workspace_members(user_id);
CREATE INDEX idx_wm_token ON workspace_members(invite_token);

-- ================================================================
-- SCHRITT 5: VERTRIEBLER-ZUORDNUNGEN
-- ================================================================

CREATE TABLE rep_assignments (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  company_workspace_id  UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,

  role                  TEXT NOT NULL CHECK (role IN ('closer', 'setter', 'coldcaller')),

  goal_monthly          NUMERIC DEFAULT 0,
  commission_closer     NUMERIC DEFAULT 0,
  commission_setter     NUMERIC DEFAULT 0,

  via_agency_id         UUID REFERENCES workspaces(id),

  invited_by            UUID REFERENCES auth.users(id),
  invited_at            TIMESTAMPTZ DEFAULT NOW(),
  joined_at             TIMESTAMPTZ,
  invite_token          TEXT UNIQUE DEFAULT gen_random_uuid()::TEXT,

  is_active             BOOLEAN DEFAULT TRUE,

  UNIQUE(user_id, company_workspace_id)
);

CREATE INDEX idx_ra_user ON rep_assignments(user_id);
CREATE INDEX idx_ra_company ON rep_assignments(company_workspace_id);
CREATE INDEX idx_ra_agency ON rep_assignments(via_agency_id);

-- ================================================================
-- SCHRITT 6: MENTEES (Vertriebler in Agentur-Ausbildung)
-- ================================================================

CREATE TABLE mentees (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  agency_workspace_id   UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,

  status                TEXT DEFAULT 'active' CHECK (status IN ('active','graduated','inactive')),

  invited_by            UUID REFERENCES auth.users(id),
  invited_at            TIMESTAMPTZ DEFAULT NOW(),
  joined_at             TIMESTAMPTZ,
  invite_token          TEXT UNIQUE DEFAULT gen_random_uuid()::TEXT,

  enrolled_at           TIMESTAMPTZ DEFAULT NOW(),
  graduated_at          TIMESTAMPTZ,

  UNIQUE(user_id, agency_workspace_id)
);

-- ================================================================
-- SCHRITT 7: AGENCY ↔ COMPANY LINKS
-- ================================================================

CREATE TABLE agency_company_links (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  agency_workspace_id   UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  company_workspace_id  UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(agency_workspace_id, company_workspace_id)
);

CREATE INDEX idx_acl_agency ON agency_company_links(agency_workspace_id);
CREATE INDEX idx_acl_company ON agency_company_links(company_workspace_id);

-- ================================================================
-- SCHRITT 8: TRACKING ENTRIES
-- ================================================================

CREATE TABLE tracking_entries (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  company_workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  entry_date        DATE NOT NULL,
  role              TEXT,

  brutto            INTEGER,
  netto             INTEGER,
  termine           INTEGER,
  sales_calls       INTEGER,
  absagen           INTEGER,
  no_shows          INTEGER,
  stattgefunden     INTEGER,
  abschluesse       INTEGER,
  umsatz            NUMERIC,
  umsatz_upsell     NUMERIC,
  cash_collected    NUMERIC,
  notes             TEXT,

  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE(user_id, company_workspace_id, entry_date)
);

CREATE INDEX idx_te_user ON tracking_entries(user_id);
CREATE INDEX idx_te_company ON tracking_entries(company_workspace_id);
CREATE INDEX idx_te_date ON tracking_entries(entry_date);

-- ================================================================
-- SCHRITT 9: MOOD TRACKING
-- ================================================================

CREATE TABLE daily_moods (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date            DATE NOT NULL,
  energy          INTEGER CHECK (energy BETWEEN 1 AND 10),
  satisfaction    INTEGER CHECK (satisfaction BETWEEN 1 AND 10),
  motivation      INTEGER CHECK (motivation BETWEEN 1 AND 10),
  help_text       TEXT,
  UNIQUE(user_id, date)
);

-- ================================================================
-- SCHRITT 10: PUNKTE
-- ================================================================

CREATE TABLE rep_points (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  company_workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  month             INTEGER NOT NULL,
  year              INTEGER NOT NULL,
  role              TEXT NOT NULL,
  points_total      INTEGER DEFAULT 0,
  points_breakdown  JSONB DEFAULT '{}',
  UNIQUE(user_id, company_workspace_id, month, year, role)
);

-- ================================================================
-- SCHRITT 11: ZOOM ACCOUNTS
-- ================================================================

CREATE TABLE zoom_accounts (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  email           TEXT,
  display_name    TEXT,
  access_token    TEXT,
  refresh_token   TEXT,
  expires_at      TIMESTAMPTZ,
  zoom_user_info  JSONB,
  company_workspace_id UUID REFERENCES workspaces(id),
  is_personal     BOOLEAN DEFAULT FALSE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_za_user ON zoom_accounts(user_id);

-- ================================================================
-- SCHRITT 12: TRAININGS
-- ================================================================

CREATE TABLE trainings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id    UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  trainer_id      UUID NOT NULL REFERENCES auth.users(id),
  title           TEXT NOT NULL,
  description     TEXT,
  scheduled_at    TIMESTAMPTZ NOT NULL,
  zoom_meeting_id TEXT,
  target_group    TEXT DEFAULT 'all' CHECK (target_group IN ('mentees','reps','all')),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE training_attendance (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  training_id   UUID NOT NULL REFERENCES trainings(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES auth.users(id),
  status        TEXT DEFAULT 'pending' CHECK (status IN ('present','absent','pending')),
  source        TEXT DEFAULT 'manual' CHECK (source IN ('manual','zoom_auto')),
  UNIQUE(training_id, user_id)
);

-- ================================================================
-- SCHRITT 13: MONATSGEWINN
-- ================================================================

CREATE TABLE prizes (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id      UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  month             INTEGER NOT NULL,
  year              INTEGER NOT NULL,
  role              TEXT NOT NULL,
  description       TEXT,
  min_goal_pct      INTEGER DEFAULT 80,
  min_training_pct  INTEGER DEFAULT 80,
  active            BOOLEAN DEFAULT TRUE,
  UNIQUE(workspace_id, month, year, role)
);

-- ================================================================
-- SCHRITT 14: POSTFACH / INBOX
-- ================================================================

CREATE TABLE inbox_messages (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type            TEXT NOT NULL CHECK (type IN (
    'workspace_invite',
    'rep_invite',
    'mentee_invite',
    'ki_analysis_ready',
    'trainer_feedback',
    'training_reminder',
    'weekly_digest',
    'job_application',
    'job_offer',
    'system'
  )),
  title           TEXT NOT NULL,
  body            TEXT,
  read            BOOLEAN DEFAULT FALSE,
  action_url      TEXT,
  reference_id    UUID,
  reference_type  TEXT,
  invite_token    TEXT,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_inbox_recipient ON inbox_messages(recipient_id);
CREATE INDEX idx_inbox_read ON inbox_messages(recipient_id, read);

-- ================================================================
-- SCHRITT 15: TRAINER FEEDBACK
-- ================================================================

CREATE TABLE trainer_feedback (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trainer_id      UUID NOT NULL REFERENCES auth.users(id),
  recipient_id    UUID NOT NULL REFERENCES auth.users(id),
  recording_id    TEXT,
  feedback_text   TEXT NOT NULL,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ================================================================
-- SCHRITT 16: STELLENMARKT
-- ================================================================

CREATE TABLE job_postings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id    UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
  role_needed     TEXT NOT NULL CHECK (role_needed IN ('closer','setter','coldcaller','mentee')),
  title           TEXT NOT NULL,
  description     TEXT,
  commission_model TEXT,
  remote          BOOLEAN DEFAULT TRUE,
  active          BOOLEAN DEFAULT TRUE,
  expires_at      DATE,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE job_applications (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_posting_id  UUID NOT NULL REFERENCES job_postings(id) ON DELETE CASCADE,
  applicant_id    UUID NOT NULL REFERENCES auth.users(id),
  message         TEXT,
  status          TEXT DEFAULT 'pending' CHECK (status IN ('pending','accepted','rejected')),
  applied_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(job_posting_id, applicant_id)
);

-- ================================================================
-- SCHRITT 17: ADMIN IMPERSONATION LOG
-- ================================================================

CREATE TABLE admin_impersonation_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id        UUID NOT NULL REFERENCES auth.users(id),
  impersonated_id UUID NOT NULL REFERENCES auth.users(id),
  started_at      TIMESTAMPTZ DEFAULT NOW(),
  ended_at        TIMESTAMPTZ,
  reason          TEXT
);

-- ================================================================
-- SCHRITT 18: PERFORMANCE-INDIZES
-- ================================================================

CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_rep_assignments_active ON rep_assignments(user_id, is_active);
CREATE INDEX idx_tracking_user_date ON tracking_entries(user_id, entry_date DESC);
CREATE INDEX idx_tracking_company_date ON tracking_entries(company_workspace_id, entry_date DESC);
CREATE INDEX idx_moods_user_date ON daily_moods(user_id, date DESC);
CREATE INDEX idx_rep_points_lookup ON rep_points(user_id, company_workspace_id, year, month);
