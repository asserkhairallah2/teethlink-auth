-- =============================================================================
-- TeethLink Authentication & Schemas Subsystem (sql/schema.sql)
-- Clean, self-contained schema containing ONLY authentication, accounts,
-- supervisor verification, medical questionnaire catalog & safety risk flags.
-- =============================================================================

BEGIN;

DO $$ BEGIN
  CREATE EXTENSION IF NOT EXISTS citext;
EXCEPTION WHEN OTHERS THEN NULL; END $$;
DO $$ BEGIN
  CREATE EXTENSION IF NOT EXISTS pgcrypto;
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- -----------------------------------------------------------------------------
-- 1. Enums
-- -----------------------------------------------------------------------------
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM ('PATIENT', 'DOCTOR', 'SUPERVISOR', 'ADMIN');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE account_status AS ENUM (
    'PENDING_APPROVAL',
    'ACTIVE',
    'REJECTED',
    'SUSPENDED',
    'DEACTIVATED'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE gender_type AS ENUM ('MALE', 'FEMALE');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE doctor_category AS ENUM (
    'UNDERGRAD_STUDENT',
    'INTERN',
    'POSTGRAD',
    'STAFF_DOCTOR'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE availability_status AS ENUM ('AVAILABLE', 'BUSY', 'OFF_DUTY');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE risk_severity AS ENUM ('INFO', 'CAUTION', 'HIGH');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- -----------------------------------------------------------------------------
-- 2. Departments
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS departments (
  department_id BIGSERIAL PRIMARY KEY,
  code          VARCHAR(20) NOT NULL UNIQUE,
  name_en       VARCHAR(100) NOT NULL,
  name_ar       VARCHAR(100) NOT NULL,
  description   TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 3. Core Users Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  user_id            BIGSERIAL PRIMARY KEY,
  role               user_role NOT NULL,
  full_name          VARCHAR(120) NOT NULL,
  phone              VARCHAR(20) NOT NULL UNIQUE,
  email              VARCHAR(120) UNIQUE,
  password_hash      VARCHAR(255) NOT NULL,
  account_status     account_status NOT NULL DEFAULT 'PENDING_APPROVAL',
  preferred_language VARCHAR(5) NOT NULL DEFAULT 'ar',
  rejection_reason   TEXT,
  approved_by        BIGINT REFERENCES users(user_id),
  approved_at        TIMESTAMPTZ,
  token_version      INTEGER NOT NULL DEFAULT 0,
  last_login_at      TIMESTAMPTZ,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at         TIMESTAMPTZ,
  CONSTRAINT ck_user_phone CHECK (phone ~ '^\+?[0-9]{10,16}$')
);

CREATE INDEX IF NOT EXISTS idx_users_role_status ON users(role, account_status) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email) WHERE email IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 4. Supervisor Profiles
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS supervisor_profiles (
  supervisor_id      BIGINT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
  supervisor_code    VARCHAR(12) NOT NULL UNIQUE,
  department_id      BIGINT REFERENCES departments(department_id),
  title              VARCHAR(60),
  specialty          VARCHAR(120),
  is_triage_examiner BOOLEAN NOT NULL DEFAULT TRUE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 5. Student Doctor Profiles
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS student_doctor_profiles (
  doctor_id            BIGINT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
  doctor_category      doctor_category NOT NULL DEFAULT 'UNDERGRAD_STUDENT',
  university_id_number VARCHAR(30) NOT NULL UNIQUE,
  university           VARCHAR(120) NOT NULL DEFAULT 'October 6 University',
  college              VARCHAR(120) NOT NULL DEFAULT 'Faculty of Dentistry',
  academic_year        SMALLINT NOT NULL DEFAULT 5,
  supervisor_id        BIGINT REFERENCES supervisor_profiles(supervisor_id),
  availability_status  availability_status NOT NULL DEFAULT 'AVAILABLE',
  max_active_cases     SMALLINT NOT NULL DEFAULT 5,
  photo_url            TEXT,
  id_card_url          TEXT,
  id_proof_file_id     BIGINT,
  bio                  TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT ck_student_year CHECK (academic_year BETWEEN 1 AND 7)
);

CREATE INDEX IF NOT EXISTS idx_students_supervisor ON student_doctor_profiles(supervisor_id);

-- -----------------------------------------------------------------------------
-- 6. Doctor Department Assignments
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS doctor_departments (
  doctor_id     BIGINT NOT NULL REFERENCES student_doctor_profiles(doctor_id) ON DELETE CASCADE,
  department_id BIGINT NOT NULL REFERENCES departments(department_id) ON DELETE RESTRICT,
  is_primary    BOOLEAN NOT NULL DEFAULT FALSE,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  assigned_by   BIGINT REFERENCES users(user_id),
  assigned_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (doctor_id, department_id)
);

-- -----------------------------------------------------------------------------
-- 7. Patient Profiles & Photo Consent
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS patient_profiles (
  patient_id                 BIGINT PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
  full_name                  VARCHAR(120),
  age                        SMALLINT,
  date_of_birth              DATE,
  gender                     gender_type,
  national_id                VARCHAR(14),
  address_area               VARCHAR(120),
  emergency_contact_phone    VARCHAR(20),
  photo_url                  TEXT,
  photo_consent              BOOLEAN NOT NULL DEFAULT FALSE,
  photo_consent_updated_at   TIMESTAMPTZ,
  has_critical_condition     BOOLEAN NOT NULL DEFAULT FALSE,
  medical_document_status    VARCHAR(30) NOT NULL DEFAULT 'NOT_REQUIRED',
  medical_attachment_url     TEXT,
  questionnaire_completed_at TIMESTAMPTZ,
  data_sharing_consent_at    TIMESTAMPTZ,
  medical_notes              TEXT,
  created_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                 TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 8. Medical Questionnaire Catalog
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS medical_conditions (
  condition_id             BIGSERIAL PRIMARY KEY,
  code                     VARCHAR(50) NOT NULL UNIQUE,
  category                 VARCHAR(80) NOT NULL,
  name_en                  VARCHAR(150) NOT NULL,
  name_ar                  VARCHAR(150) NOT NULL,
  question_text_en         TEXT NOT NULL,
  question_text_ar         TEXT NOT NULL,
  is_critical              BOOLEAN NOT NULL DEFAULT FALSE,
  requires_document_if_yes BOOLEAN NOT NULL DEFAULT FALSE,
  checklist_options        JSONB NOT NULL DEFAULT '[]'::jsonb,
  risk_severity            risk_severity NOT NULL DEFAULT 'INFO',
  is_active                BOOLEAN NOT NULL DEFAULT TRUE,
  display_order            SMALLINT NOT NULL DEFAULT 100
);

-- -----------------------------------------------------------------------------
-- 9. Patient Conditions Responses
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS patient_conditions (
  patient_condition_id BIGSERIAL PRIMARY KEY,
  patient_id           BIGINT NOT NULL REFERENCES patient_profiles(patient_id) ON DELETE CASCADE,
  condition_id         BIGINT NOT NULL REFERENCES medical_conditions(condition_id),
  has_condition        BOOLEAN NOT NULL DEFAULT TRUE,
  details              TEXT,
  document_status      VARCHAR(30) NOT NULL DEFAULT 'NOT_REQUIRED',
  selected_options     JSONB NOT NULL DEFAULT '[]'::jsonb,
  answered_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_patient_condition UNIQUE (patient_id, condition_id)
);

CREATE INDEX IF NOT EXISTS idx_pc_patient ON patient_conditions(patient_id);

-- -----------------------------------------------------------------------------
-- 10. Patient Medications
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS patient_medications (
  medication_id    BIGSERIAL PRIMARY KEY,
  patient_id       BIGINT NOT NULL REFERENCES patient_profiles(patient_id) ON DELETE CASCADE,
  medication_name  VARCHAR(120) NOT NULL,
  dosage           VARCHAR(80),
  frequency        VARCHAR(60),
  is_anticoagulant BOOLEAN NOT NULL DEFAULT FALSE,
  notes            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_pmed_patient ON patient_medications(patient_id);

-- -----------------------------------------------------------------------------
-- 11. Allergies Catalog
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS allergies (
  allergy_id    BIGSERIAL PRIMARY KEY,
  code          VARCHAR(50) NOT NULL UNIQUE,
  name_en       VARCHAR(120) NOT NULL,
  name_ar       VARCHAR(120) NOT NULL,
  risk_severity risk_severity NOT NULL DEFAULT 'CAUTION',
  is_active     BOOLEAN NOT NULL DEFAULT TRUE
);

-- -----------------------------------------------------------------------------
-- 12. Patient Allergies Responses
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS patient_allergies (
  patient_allergy_id BIGSERIAL PRIMARY KEY,
  patient_id         BIGINT NOT NULL REFERENCES patient_profiles(patient_id) ON DELETE CASCADE,
  allergy_id         BIGINT NOT NULL REFERENCES allergies(allergy_id),
  notes              TEXT,
  diagnosed_at       DATE,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_patient_allergy UNIQUE (patient_id, allergy_id)
);

CREATE INDEX IF NOT EXISTS idx_pallergy_patient ON patient_allergies(patient_id);

-- -----------------------------------------------------------------------------
-- 13. Audit Logs
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
  log_id        BIGSERIAL PRIMARY KEY,
  actor_user_id BIGINT REFERENCES users(user_id),
  actor_role    VARCHAR(40),
  action        VARCHAR(80) NOT NULL,
  entity_type   VARCHAR(60) NOT NULL,
  entity_id     BIGINT,
  before_data   JSONB,
  after_data    JSONB,
  ip_address    VARCHAR(45),
  user_agent    VARCHAR(255),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_actor ON audit_logs(actor_user_id);

-- -----------------------------------------------------------------------------
-- 14. Refresh Tokens
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS refresh_tokens (
  token_id    BIGSERIAL PRIMARY KEY,
  user_id     BIGINT      NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  token_hash  VARCHAR(64) NOT NULL UNIQUE,
  family_id   UUID        NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL,
  revoked_at  TIMESTAMPTZ,
  user_agent  TEXT,
  ip_address  INET,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_rt_user ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_rt_hash ON refresh_tokens(token_hash);

-- -----------------------------------------------------------------------------
-- 14. Computed Risk Flags View (v_patient_risk_flags)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_patient_risk_flags AS
SELECT
  pc.patient_id,
  mc.condition_id AS risk_flag_id,
  mc.code,
  mc.name_en,
  mc.name_ar,
  mc.risk_severity AS severity,
  'CONDITION'::text AS source,
  mc.code AS source_code
FROM patient_conditions pc
JOIN medical_conditions mc ON mc.condition_id = pc.condition_id
WHERE pc.has_condition = TRUE AND mc.is_active = TRUE

UNION ALL

SELECT
  pa.patient_id,
  (1000 + a.allergy_id) AS risk_flag_id,
  a.code,
  ('Allergy: ' || a.name_en)::varchar(150) AS name_en,
  ('حساسية: ' || a.name_ar)::varchar(150) AS name_ar,
  a.risk_severity AS severity,
  'ALLERGY'::text AS source,
  a.code AS source_code
FROM patient_allergies pa
JOIN allergies a ON a.allergy_id = pa.allergy_id
WHERE a.is_active = TRUE;

COMMIT;
