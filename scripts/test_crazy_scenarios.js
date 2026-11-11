// TeethLink_Auth_System/scripts/test_crazy_scenarios.js
// Exhaustive test suite testing normal flows + bizarre, crazy, edge-case, and adversarial scenarios!

const BASE_URL = 'http://localhost:5000';
const API_URL = `${BASE_URL}/api/v1`;

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(condition, testName, details = '') {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`  ✅ [PASS] ${testName}`);
  } else {
    failedTests++;
    console.error(`  ❌ [FAIL] ${testName} ${details ? '--> ' + details : ''}`);
  }
}

async function request(endpoint, options = {}) {
  const url = endpoint.startsWith('http') ? endpoint : `${API_URL}${endpoint}`;
  try {
    const res = await fetch(url, options);
    let data = null;
    const contentType = res.headers.get('content-type') || '';
    if (contentType.includes('application/json')) {
      data = await res.json();
    } else {
      data = await res.text();
    }
    return { status: res.status, headers: res.headers, data };
  } catch (err) {
    return { status: 0, error: err.message };
  }
}

async function run() {
  console.log('\n============================================================');
  console.log('  TEETHLINK AUTH & SCHEMAS SUBSYSTEM — STRESS & CRAZY TESTS');
  console.log('============================================================\n');

  const ts = Date.now().toString().slice(-6);

  // ---------------------------------------------------------------------------
  // 1. HEALTH & STATIC ASSETS
  // ---------------------------------------------------------------------------
  console.log('📋 1. SYSTEM HEALTH & STATIC ASSETS (SCHEMAS & DIAGRAMS)');
  const health = await request('/health');
  assert(health.status === 200 && health.data?.data?.database?.connected, 'Health check returns 200 and database connected');

  const gui = await request(`${BASE_URL}/`);
  assert(gui.status === 200 && gui.data.includes('TeethLink'), 'GUI index.html served correctly');

  const authSvg = await request(`${BASE_URL}/diagrams/01_auth_medical_schema.svg`);
  assert(authSvg.status === 200 && authSvg.data.includes('<svg'), 'Auth ERD SVG served');

  const fullSvg = await request(`${BASE_URL}/diagrams/02_full_system_schema.svg`);
  assert(fullSvg.status === 200 && fullSvg.data.includes('<svg'), 'Full 24-Entity Schema ERD SVG served');

  const authSql = await request(`${BASE_URL}/sql/auth_schema.sql`);
  assert(authSql.status === 200 && authSql.data.includes('CREATE TABLE'), 'Auth SQL DDL download served');

  const fullSql = await request(`${BASE_URL}/sql/full_system_schema.sql`);
  assert(fullSql.status === 200 && fullSql.data.includes('CREATE TABLE'), 'Full System SQL DDL download served');

  // ---------------------------------------------------------------------------
  // 2. NORMAL SUCCESSFUL FLOWS
  // ---------------------------------------------------------------------------
  console.log('\n📋 2. NORMAL AUTHENTICATION JOURNEYS');

  // Patient registration with full questionnaire
  const patientPhone = `+201011${ts}01`;
  const regPatient = await request('/auth/register/patient', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fullName: `Sara Hassan ${ts}`,
      phone: patientPhone,
      email: `sara.${ts}@test.com`,
      password: 'Patient@12345',
      photoConsent: true,
      dataSharingConsent: true,
      medicalQuestionnaire: {
        conditions: [
          { conditionId: 1, hasCondition: true, details: 'Type 2 Diabetes' }
        ],
        allergies: [{ allergyId: 1, notes: 'Penicillin allergy' }],
        documentDelivery: 'WILL_BRING_PHYSICALLY'
      }
    })
  });
  assert(regPatient.status === 201 && regPatient.data?.success, 'Patient registered with questionnaire');
  const patientId = regPatient.data?.data?.user?.userId || regPatient.data?.data?.userId;

  // Student registration linking to Supervisor 4
  const studentPhone = `+201011${ts}02`;
  const regStudent = await request('/auth/register/doctor', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fullName: `Omar Khaled ${ts}`,
      phone: studentPhone,
      email: `omar.${ts}@o6u.edu.eg`,
      password: 'Doctor@12345',
      universityIdNumber: `STU-OK-${ts}`,
      university: 'October 6 University',
      college: 'Faculty of Dentistry',
      academicYear: 5,
      supervisorCode: '4'
    })
  });
  assert(regStudent.status === 201 && regStudent.data?.data?.accountStatus === 'PENDING_APPROVAL', 'Student registered with Supervisor ID 4');
  const studentId = regStudent.data?.data?.userId;

  // Supervisor registration with Department ID
  const supPhone = `+201011${ts}03`;
  const regSup = await request('/auth/register/supervisor', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fullName: `Dr. Nadia Samir ${ts}`,
      phone: supPhone,
      email: `nadia.${ts}@o6u.edu.eg`,
      password: 'Supervisor@12345',
      departmentId: 4,
      title: 'Assoc. Prof. Dr.',
      specialty: 'Periodontics'
    })
  });
  assert(regSup.status === 201 && regSup.data?.data?.accountStatus === 'PENDING_APPROVAL', 'Supervisor registered with department');
  const supervisorId = regSup.data?.data?.userId;

  // Admin login & approval
  const adminLogin = await request('/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identifier: '+201000000001', password: 'Admin@12345' })
  });
  assert(adminLogin.status === 200 && adminLogin.data?.data?.accessToken, 'Admin logged in');
  const adminToken = adminLogin.data?.data?.accessToken;

  // Admin approves student
  const approveStudent = await request(`/admin/accounts/${studentId}/approve`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${adminToken}` },
    body: JSON.stringify({ departmentIds: [1, 2, 4] })
  });
  assert(approveStudent.status === 200 && approveStudent.data?.success, 'Admin approved student account');

  // Admin approves supervisor
  const approveSup = await request(`/admin/accounts/${supervisorId}/approve`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${adminToken}` },
    body: JSON.stringify({ supervisorCode: `SUP-${supervisorId}` })
  });
  assert(approveSup.status === 200 && approveSup.data?.success, 'Admin approved supervisor account');

  // Approved student logs in
  const studentLogin = await request('/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identifier: studentPhone, password: 'Doctor@12345' })
  });
  assert(studentLogin.status === 200 && studentLogin.data?.data?.user?.accountStatus === 'ACTIVE', 'Approved student logged in as ACTIVE');

  // ---------------------------------------------------------------------------
  // 3. CRAZY & ADVERSARIAL SCENARIOS ("سيناريوهات متخلفة")
  // ---------------------------------------------------------------------------
  console.log('\n📋 3. CRAZY & ADVERSARIAL SCENARIOS ("سيناريوهات متخلفة و Edge Cases")');

  // 3A. SQL Injection in Phone Number
  const sqliPhone = await request('/auth/register/patient', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fullName: 'Hacker Joe',
      phone: "'+201000000001' OR 1=1; DROP TABLE users; --",
      password: 'Hacker@12345',
      dataSharingConsent: true,
      medicalQuestionnaire: { conditions: [] }
    })
  });
  assert(sqliPhone.status === 400, 'SQL injection in phone rejected with 400 validation error');

  // 3B. SQL Injection in Login Email
  const sqliLogin = await request('/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      identifier: "admin@teethlink.edu.eg' OR '1'='1",
      password: "password' OR '1'='1"
    })
  });
  assert(sqliLogin.status === 401 || sqliLogin.status === 400, 'SQL injection login bypass prevented safely');

  // 3C. XSS Injection in Name and Medical Notes
  const xssPhone = `+201011${ts}04`;
  const xssReg = await request('/auth/register/patient', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fullName: '<script>alert("XSS")</script> Ahmed',
      phone: xssPhone,
      password: 'Patient@12345',
      dataSharingConsent: true,
      medicalQuestionnaire: {
        conditions: [],
        medicalNotes: '<img src=x onerror=alert(1)>'
      }
    })
  });
  assert(xssReg.status === 201, 'XSS input stored safely as raw text without server crash');

  // 3D. Boundary attack: Negative academic year
  const negYear = await request('/auth/register/doctor', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fullName: 'Dr. Negative',
      phone: `+201011${ts}05`,
      password: 'Doctor@12345',
      universityIdNumber: `STU-NEG-${ts}`,
      academicYear: -5,
      supervisorCode: '4'
    })
  });
  assert(negYear.status === 400, 'Negative academic year (-5) rejected with 400 validation error');

  // 3E. Boundary attack: Absurdly large academic year (year 99)
  const hugeYear = await request('/auth/register/doctor', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fullName: 'Dr. HugeYear',
      phone: `+201011${ts}06`,
      password: 'Doctor@12345',
      universityIdNumber: `STU-HUGE-${ts}`,
      academicYear: 99,
      supervisorCode: '4'
    })
  });
  assert(hugeYear.status === 400, 'Absurd academic year (99) rejected with 400 validation error');

  // 3F. Floating point academic year (4.8)
  const floatYear = await request('/auth/register/doctor', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fullName: 'Dr. Float',
      phone: `+201011${ts}07`,
      password: 'Doctor@12345',
      universityIdNumber: `STU-FLT-${ts}`,
      academicYear: 4.8,
      supervisorCode: '4'
    })
  });
  assert(floatYear.status === 400, 'Float academic year (4.8) rejected with 400 validation error');

  // 3G. Duplicate Phone Number conflict
  const dupPhone = await request('/auth/register/patient', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fullName: 'Duplicate Sara',
      phone: patientPhone, // already used!
      password: 'Patient@12345',
      dataSharingConsent: true,
      medicalQuestionnaire: { conditions: [] }
    })
  });
  assert(dupPhone.status === 409 && dupPhone.data?.error?.code === 'DUPLICATE_RESOURCE', 'Duplicate phone registration rejected with 409 DUPLICATE_RESOURCE');

  // 3H. Duplicate Student University ID Number
  const dupStuId = await request('/auth/register/doctor', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fullName: 'Duplicate Student ID',
      phone: `+201011${ts}08`,
      password: 'Doctor@12345',
      universityIdNumber: `STU-OK-${ts}`, // already used!
      academicYear: 5,
      supervisorCode: '4'
    })
  });
  assert(dupStuId.status === 409 && dupStuId.data?.error?.code === 'DUPLICATE_RESOURCE', 'Duplicate student university ID rejected with 409 DUPLICATE_RESOURCE');

  // 3I. Student linking to Non-Existent Supervisor Code
  const fakeSup = await request('/auth/register/doctor', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fullName: 'Dr. Orphan Student',
      phone: `+201011${ts}09`,
      password: 'Doctor@12345',
      universityIdNumber: `STU-ORPH-${ts}`,
      academicYear: 5,
      supervisorCode: 'SUP-9999'
    })
  });
  assert(fakeSup.status === 422 && fakeSup.data?.error?.code === 'INVALID_SUPERVISOR_CODE', 'Non-existent supervisor code returns 422 INVALID_SUPERVISOR_CODE');

  // 3J. Supervisor Verify endpoint with bizarre inputs
  const verifyEmoji = await request('/auth/supervisors/verify/🦷👨‍⚕️');
  assert(verifyEmoji.status === 404, 'Emoji supervisor code verify gracefully returns 404');

  const verifyNeg = await request('/auth/supervisors/verify/-99999');
  assert(verifyNeg.status === 404, 'Negative supervisor code verify gracefully returns 404');

  // 3K. Approving a non-existent User ID (ID: 9999999)
  const approveGhost = await request('/admin/accounts/9999999/approve', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${adminToken}` },
    body: JSON.stringify({ departmentIds: [1] })
  });
  assert(approveGhost.status === 404 && approveGhost.data?.error?.code === 'USER_NOT_FOUND', 'Approving non-existent user returns 404 USER_NOT_FOUND');

  // 3L. Rejecting without a reason (empty or 1 character)
  const rejectEmpty = await request(`/admin/accounts/${patientId}/reject`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${adminToken}` },
    body: JSON.stringify({ reason: ' ' })
  });
  assert(rejectEmpty.status === 400, 'Rejection without reason rejected with 400 validation error');

  // 3M. Proper Admin Rejection with reason
  const rejectValid = await request(`/admin/accounts/${patientId}/reject`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${adminToken}` },
    body: JSON.stringify({ reason: 'Incomplete contact information provided.' })
  });
  assert(rejectValid.status === 200 && rejectValid.data?.success, 'Rejection with valid reason succeeds');

  // 3N. Rejected user login blocked
  const rejectedLogin = await request('/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ identifier: patientPhone, password: 'Patient@12345' })
  });
  assert(rejectedLogin.status === 403, 'Rejected user login is blocked with 403 Forbidden');

  // 3O. Authentication attacks: Access Admin routes without Token
  const noToken = await request('/admin/accounts/pending');
  assert(noToken.status === 401, 'Accessing admin routes without token returns 401 Unauthorized');

  // 3P. Authentication attacks: Access Admin routes with Fake/Tampered Token
  const fakeToken = await request('/admin/accounts/pending', {
    headers: { 'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.fake.signature' }
  });
  assert(fakeToken.status === 401, 'Accessing admin routes with forged token returns 401 Unauthorized');

  // 3Q. Authentication attacks: Access Admin routes with Student Doctor Token (Privilege Escalation)
  const studentToken = studentLogin.data?.data?.accessToken;
  const privEscalation = await request('/admin/accounts/pending', {
    headers: { 'Authorization': `Bearer ${studentToken}` }
  });
  assert(privEscalation.status === 403, 'Student token accessing admin routes blocked with 403 Forbidden');

  // 3R. Missing mandatory dataSharingConsent
  const noConsent = await request('/auth/register/patient', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      fullName: 'No Consent Patient',
      phone: `+201011${ts}99`,
      password: 'Patient@12345',
      dataSharingConsent: false, // Refused!
      medicalQuestionnaire: { conditions: [] }
    })
  });
  assert(noConsent.status === 400, 'Missing mandatory dataSharingConsent returns 400 validation error');

  // ---------------------------------------------------------------------------
  // SUMMARY
  // ---------------------------------------------------------------------------
  console.log('\n============================================================');
  console.log(`  ALL CRAZY & EDGE-CASE TESTS COMPLETE: ${passedTests} PASSED / ${failedTests} FAILED (TOTAL: ${totalTests})`);
  console.log('============================================================\n');

  if (failedTests > 0) {
    process.exit(1);
  }
}

run().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
