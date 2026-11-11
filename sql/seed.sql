-- =============================================================================
-- TeethLink Authentication & Schemas Subsystem (sql/seed.sql)
-- Initial seed data: Departments, Medical Catalog, Allergies, and Demo Accounts.
-- =============================================================================

BEGIN;

-- 1. Clinical Departments (7 University Departments)
INSERT INTO departments (department_id, code, name_en, name_ar, description)
VALUES
  (1, 'REST', 'Restorative & Operative Dentistry', 'علاج الجذور والتحفظي', 'Operative fillings, composite restorations, cosmetic dentistry'),
  (2, 'SURG', 'Oral & Maxillofacial Surgery', 'جراحة الفم والوجه والفكين', 'Extractions, minor oral surgery, impactions, biopsies'),
  (3, 'ENDO', 'Endodontics', 'علاج جذور الأسنان', 'Root canal treatments, pulpotomies, endodontic retreatment'),
  (4, 'PERIO', 'Periodontics', 'طب وجراحة اللثة', 'Scaling, root planing, gum surgeries, periodontal disease'),
  (5, 'PROS', 'Prosthodontics', 'الاستعاضة الصناعية والتركيبات', 'Crowns, bridges, complete & partial dentures'),
  (6, 'PEDO', 'Pediatric Dentistry', 'طب أسنان الأطفال', 'Preventive care, pulpotomies, space maintainers for children'),
  (7, 'ORTHO', 'Orthodontics', 'تقويم الأسنان وتعديل الفكين', 'Malocclusion alignment, space management, diagnostic casts')
ON CONFLICT (department_id) DO UPDATE
SET name_en = EXCLUDED.name_en, name_ar = EXCLUDED.name_ar, is_active = TRUE;

SELECT setval('departments_department_id_seq', (SELECT MAX(department_id) FROM departments));

-- 2. Medical Conditions (10 Conditions: 5 Critical + 5 Routine)
INSERT INTO medical_conditions (
  condition_id, code, category, name_en, name_ar,
  question_text_en, question_text_ar, is_critical, requires_document_if_yes, risk_severity, display_order
)
VALUES
  (1, 'DIABETES', 'Endocrine', 'Diabetes', 'مرض السكري',
   'Do you have Diabetes (Type 1 or 2)?', 'هل تعاني من مرض السكري؟', TRUE, TRUE, 'HIGH', 10),
  (2, 'HYPERTENSION', 'Cardiovascular', 'High blood pressure', 'ارتفاع ضغط الدم',
   'Do you suffer from high blood pressure?', 'هل تعاني من ارتفاع ضغط الدم؟', TRUE, TRUE, 'HIGH', 20),
  (3, 'HEART_DISEASE', 'Cardiovascular', 'Heart disease', 'أمراض القلب والشرايين',
   'Do you have any heart disease or previous heart surgery?', 'هل تعاني من أمراض القلب أو خضعت لجراحة قلب؟', TRUE, TRUE, 'HIGH', 30),
  (4, 'ANTICOAGULANT_BLEEDING', 'Hematologic', 'Blood thinners or bleeding disorder', 'سيولة الدم أو أدوية التجلط',
   'Do you take blood thinners or have a bleeding disorder?', 'هل تتناول أدوية سيولة الدم أو تعاني من نزيف؟', TRUE, TRUE, 'HIGH', 40),
  (5, 'KIDNEY_LIVER', 'Systemic', 'Kidney or liver disease', 'أمراض الكلى أو الكبد',
   'Do you have chronic kidney or liver disease?', 'هل تعاني من أمراض مزمنة في الكلى أو الكبد؟', TRUE, TRUE, 'HIGH', 50),
  (6, 'ASTHMA_EPILEPSY', 'Neurologic_Respiratory', 'Asthma or epilepsy', 'الربو أو الصرع',
   'Do you have asthma, seizures, or epilepsy?', 'هل تعاني من حساسية الصدر، الربو، أو الصرع؟', FALSE, FALSE, 'CAUTION', 60),
  (7, 'THYROID', 'Endocrine', 'Thyroid disorder', 'اضطرابات الغدة الدرقية',
   'Do you suffer from hyperthyroidism or hypothyroidism?', 'هل تعاني من اضطراب في الغدة الدرقية؟', FALSE, FALSE, 'CAUTION', 70),
  (8, 'PREGNANCY', 'Physiologic', 'Pregnancy or breastfeeding', 'الحمل أو الرضاعة',
   'Are you currently pregnant or breastfeeding?', 'هل أنتِ حامل أو في فترة الرضاعة؟', FALSE, FALSE, 'CAUTION', 80),
  (9, 'BONE_RADIOTHERAPY', 'Oncology_Bone', 'Bone treatment or head/neck radiotherapy', 'علاج العظام أو إشعاع الرأس/الرقبة',
   'Have you received bisphosphonates or head/neck radiation?', 'هل تلقيت علاجاً بهشاشة العظام أو علاجاً إشعاعياً؟', FALSE, FALSE, 'HIGH', 90),
  (10, 'SMOKING', 'Habit', 'Smoking', 'التدخين',
   'Do you currently smoke or use tobacco products?', 'هل تدخن سجائر أو شيشة بشكل منتظم؟', FALSE, FALSE, 'INFO', 100)
ON CONFLICT (condition_id) DO UPDATE
SET name_en = EXCLUDED.name_en, name_ar = EXCLUDED.name_ar, is_critical = EXCLUDED.is_critical;

SELECT setval('medical_conditions_condition_id_seq', (SELECT MAX(condition_id) FROM medical_conditions));

-- 3. Allergies (6 Common Dental Allergies)
INSERT INTO allergies (allergy_id, code, name_en, name_ar, risk_severity)
VALUES
  (1, 'PENICILLIN', 'Penicillin or other antibiotics', 'البنسلين والمضادات الحيوية', 'HIGH'),
  (2, 'LOCAL_ANESTHETIC', 'Local anaesthetic', 'بنج الأسنان الموضعي', 'HIGH'),
  (3, 'ASPIRIN_NSAIDS', 'Aspirin or NSAIDs', 'الأسبرين ومسكنات الألم', 'CAUTION'),
  (4, 'LATEX', 'Latex gloves / rubber materials', 'اللاتكس والقفازات المطاطية', 'CAUTION'),
  (5, 'SULFA', 'Sulfa drugs', 'أدوية السلفا', 'CAUTION'),
  (6, 'METALS', 'Metals / Nickel in dental materials', 'المعادن والنيكل', 'INFO')
ON CONFLICT (allergy_id) DO UPDATE
SET name_en = EXCLUDED.name_en, name_ar = EXCLUDED.name_ar;

SELECT setval('allergies_allergy_id_seq', (SELECT MAX(allergy_id) FROM allergies));

-- 4. Initial Demo Accounts
-- Passwords:
--   Admin:      Admin@12345      ($2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy)
--   Supervisor: Supervisor@12345 ($2a$10$Wd3bEfvz7Xw8/X0q2Z1f7uVbXg4oYF2M9Hw2F3n.T6a.J4l/N0mK.)
--   Doctor:     Doctor@12345     ($2a$10$7Zz3D1F2o9Y8A7b6c5D4E3F2A1B0C9D8E7F6A5B4C3D2E1F0A9B8C)
--   Patient:    Patient@12345    ($2a$10$a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a)

-- 4a. Admin Account (User ID 1)
INSERT INTO users (user_id, role, full_name, phone, email, password_hash, account_status, preferred_language)
VALUES (
  1,
  'ADMIN',
  'System Administrator',
  '+201000000001',
  'admin@teethlink.edu.eg',
  '$2a$10$WCTm78cqG2jP8W5RoUs9zO0xNKEqi3N20G2GGNjlWJXcNgY35wyem',
  'ACTIVE',
  'ar'
) ON CONFLICT (user_id) DO UPDATE SET password_hash = EXCLUDED.password_hash, account_status = 'ACTIVE';

-- 4b. Primary Supervisor: Dr. Hany Mahmoud (User ID 2, Sup ID '4' / SUP-0001)
INSERT INTO users (user_id, role, full_name, phone, email, password_hash, account_status, preferred_language)
VALUES (
  2,
  'SUPERVISOR',
  'Dr. Hany Mahmoud',
  '+201000000002',
  'hany.mahmoud@teethlink.edu.eg',
  '$2a$10$6ZkWJ5UDi6ai3dhQk2GtJuMpVTrEJlEmqCUWG6fpmL4IC6uPYRqui',
  'ACTIVE',
  'ar'
) ON CONFLICT (user_id) DO UPDATE SET password_hash = EXCLUDED.password_hash, account_status = 'ACTIVE';

INSERT INTO supervisor_profiles (supervisor_id, supervisor_code, department_id, title, specialty, is_triage_examiner)
VALUES (2, 'SUP-0001', 1, 'Assoc. Prof. Dr.', 'Restorative Dentistry & Operative Care', TRUE)
ON CONFLICT (supervisor_id) DO UPDATE SET supervisor_code = 'SUP-0001';

-- 4c. Secondary Supervisor: Dr. Mona Adel (User ID 3, Sup ID '7' / SUP-0002)
INSERT INTO users (user_id, role, full_name, phone, email, password_hash, account_status, preferred_language)
VALUES (
  3,
  'SUPERVISOR',
  'Dr. Mona Adel',
  '+201000000003',
  'mona.adel@teethlink.edu.eg',
  '$2a$10$6ZkWJ5UDi6ai3dhQk2GtJuMpVTrEJlEmqCUWG6fpmL4IC6uPYRqui',
  'ACTIVE',
  'ar'
) ON CONFLICT (user_id) DO UPDATE SET password_hash = EXCLUDED.password_hash, account_status = 'ACTIVE';

INSERT INTO supervisor_profiles (supervisor_id, supervisor_code, department_id, title, specialty, is_triage_examiner)
VALUES (3, 'SUP-0002', 2, 'Professor', 'Oral & Maxillofacial Surgery', TRUE)
ON CONFLICT (supervisor_id) DO UPDATE SET supervisor_code = 'SUP-0002';

-- 4d. Student Doctor: Dr. Omar Khaled (User ID 4, Linked to Supervisor ID 4)
INSERT INTO users (user_id, role, full_name, phone, email, password_hash, account_status, preferred_language)
VALUES (
  4,
  'DOCTOR',
  'Dr. Omar Khaled',
  '+201000000101',
  'omar.khaled@o6u.edu.eg',
  '$2a$10$2eESnd34eE8hz7TwCuMHpulF3Xj8BEeyWczShXSIKtYfDoxExox7a',
  'ACTIVE',
  'ar'
) ON CONFLICT (user_id) DO UPDATE SET password_hash = EXCLUDED.password_hash, account_status = 'ACTIVE';

INSERT INTO student_doctor_profiles (
  doctor_id, doctor_category, university_id_number, university, college, academic_year, supervisor_id, availability_status
)
VALUES (4, 'UNDERGRAD_STUDENT', 'STU-2026-001', 'October 6 University', 'Faculty of Dentistry', 5, 2, 'AVAILABLE')
ON CONFLICT (doctor_id) DO UPDATE SET supervisor_id = 2;

INSERT INTO doctor_departments (doctor_id, department_id, is_primary, is_active)
VALUES (4, 1, TRUE, TRUE), (4, 2, FALSE, TRUE), (4, 4, FALSE, TRUE)
ON CONFLICT (doctor_id, department_id) DO NOTHING;

-- 4e. Patient: Sara Ahmed Hassan (User ID 5, Diabetic + Penicillin allergy)
INSERT INTO users (user_id, role, full_name, phone, email, password_hash, account_status, preferred_language)
VALUES (
  5,
  'PATIENT',
  'Sara Ahmed Hassan',
  '+201000000201',
  'sara.hassan@gmail.com',
  '$2a$10$phGVNbiH8FZOZlRvzab7fOkhNgyr7xIh.TMY3pdDV5gFhZFGrDr1a',
  'ACTIVE',
  'ar'
) ON CONFLICT (user_id) DO UPDATE SET password_hash = EXCLUDED.password_hash, account_status = 'ACTIVE';

INSERT INTO patient_profiles (
  patient_id, full_name, age, date_of_birth, gender, national_id, photo_consent, has_critical_condition, medical_notes
)
VALUES (5, 'Sara Ahmed Hassan', 29, '1997-04-15', 'FEMALE', '29704150102345', TRUE, TRUE, 'Type 2 Diabetes, controlled on Metformin')
ON CONFLICT (patient_id) DO UPDATE SET has_critical_condition = TRUE;

INSERT INTO patient_conditions (patient_id, condition_id, has_condition, details)
VALUES (5, 1, TRUE, 'Type 2 Diabetes since 2021, regular HbA1c 6.8')
ON CONFLICT (patient_id, condition_id) DO NOTHING;

INSERT INTO patient_allergies (patient_id, allergy_id, notes)
VALUES (5, 1, 'Severe rash from Penicillin / Amoxicillin')
ON CONFLICT (patient_id, allergy_id) DO NOTHING;

SELECT setval('users_user_id_seq', (SELECT MAX(user_id) FROM users));

COMMIT;
