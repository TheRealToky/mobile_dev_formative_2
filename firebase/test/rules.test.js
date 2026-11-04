// Security Rules tests. Run from the project root with:
//   firebase emulators:exec --only firestore,storage "npm --prefix firebase test"
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
  writeBatch,
  collection,
} from 'firebase/firestore';
import { ref, uploadBytes } from 'firebase/storage';

const PROJECT_ID = 'demo-campus-reports';

let env;

// ---------- Identities ----------

const STUDENT = { uid: 'student1', email: 'ada@alustudent.com' };
const OTHER = { uid: 'student2', email: 'bo@alustudent.com' };
const STAFF = { uid: 'staff1', email: 'grace@alueducation.com' };

function as(user, { verified = true, email = user.email } = {}) {
  return env.authenticatedContext(user.uid, {
    email,
    email_verified: verified,
  });
}

const db = (ctx) => ctx.firestore();

// ---------- Fixtures ----------

function newIncident(overrides = {}) {
  return {
    title: 'Leaking tap',
    description: 'The tap in the library bathroom leaks all night.',
    category: 'water',
    status: 'submitted',
    location: { building: 'Library', detail: '2nd floor' },
    photoUrls: [],
    reporterId: STUDENT.uid,
    reporterName: 'Ada',
    isAnonymous: false,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

/** Seeds users and one incident with rules disabled. */
async function seed({ status = 'submitted' } = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const admin = ctx.firestore();
    await setDoc(doc(admin, 'users', STUDENT.uid), {
      displayName: 'Ada', email: STUDENT.email, role: 'student',
    });
    await setDoc(doc(admin, 'users', OTHER.uid), {
      displayName: 'Bo', email: OTHER.email, role: 'student',
    });
    await setDoc(doc(admin, 'users', STAFF.uid), {
      displayName: 'Grace', email: STAFF.email, role: 'staff',
    });
    await setDoc(doc(admin, 'incidents', 'inc1'), {
      ...newIncident({ status }),
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });
}

/** The batch the app's StatusController writes. */
function statusBatch(ctx, user, from, to, note = '') {
  const firestore = db(ctx);
  const incidentRef = doc(firestore, 'incidents', 'inc1');
  const eventRef = doc(collection(incidentRef, 'statusHistory'));
  const batch = writeBatch(firestore);
  batch.update(incidentRef, { status: to, updatedAt: serverTimestamp() });
  batch.set(eventRef, {
    from, to, note, changedBy: user.uid, at: serverTimestamp(),
  });
  return batch;
}

// ---------- Lifecycle ----------

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
    storage: { rules: readFileSync('../storage.rules', 'utf8') },
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
});

after(async () => {
  await env.cleanup();
});

// ---------- Access gate ----------

describe('access gate', () => {
  beforeEach(() => seed());

  it('lets a verified ALU user read incidents', async () => {
    await assertSucceeds(getDoc(doc(db(as(STUDENT)), 'incidents', 'inc1')));
  });

  it('denies unauthenticated users', async () => {
    await assertFails(
      getDoc(doc(env.unauthenticatedContext().firestore(), 'incidents', 'inc1')),
    );
  });

  it('denies unverified users', async () => {
    const ctx = as(STUDENT, { verified: false });
    await assertFails(getDoc(doc(db(ctx), 'incidents', 'inc1')));
    await assertFails(setDoc(doc(db(ctx), 'incidents', 'new'), newIncident()));
  });

  it('denies wrong-domain users, including look-alike domains', async () => {
    for (const email of ['me@gmail.com', 'me@fake-alustudent.com',
      'me@alustudent.com.evil.io']) {
      const ctx = as({ uid: 'x', email });
      await assertFails(getDoc(doc(db(ctx), 'incidents', 'inc1')));
    }
  });
});

// ---------- users ----------

describe('users/{uid}', () => {
  const profile = (role = 'student') => ({
    displayName: 'Ada',
    email: STUDENT.email,
    role,
    createdAt: serverTimestamp(),
  });

  it('allows creating your own student profile', async () => {
    await assertSucceeds(
      setDoc(doc(db(as(STUDENT)), 'users', STUDENT.uid), profile()),
    );
  });

  it('prevents self-promotion to staff', async () => {
    await assertFails(
      setDoc(doc(db(as(STUDENT)), 'users', STUDENT.uid), profile('staff')),
    );
  });

  it("prevents creating someone else's profile", async () => {
    await assertFails(
      setDoc(doc(db(as(OTHER)), 'users', STUDENT.uid), profile()),
    );
  });

  describe('existing profiles', () => {
    beforeEach(() => seed());

    it('prevents changing your role on update', async () => {
      await assertFails(
        updateDoc(doc(db(as(STUDENT)), 'users', STUDENT.uid), { role: 'staff' }),
      );
    });

    it('allows changing your display name', async () => {
      await assertSucceeds(
        updateDoc(doc(db(as(STUDENT)), 'users', STUDENT.uid), {
          displayName: 'Ada L.',
        }),
      );
    });

    it("hides other students' profiles but lets staff read them", async () => {
      await assertFails(getDoc(doc(db(as(OTHER)), 'users', STUDENT.uid)));
      await assertSucceeds(getDoc(doc(db(as(STAFF)), 'users', STUDENT.uid)));
    });
  });
});

// ---------- incidents: create ----------

describe('incidents: create', () => {
  const create = (ctx, data) => setDoc(doc(db(ctx), 'incidents', 'new'), data);

  it('accepts a valid report', async () => {
    await assertSucceeds(create(as(STUDENT), newIncident()));
  });

  it('accepts an anonymous report without a name', async () => {
    await assertSucceeds(
      create(as(STUDENT), newIncident({ isAnonymous: true, reporterName: null })),
    );
  });

  it('rejects an anonymous report that carries a name', async () => {
    await assertFails(create(as(STUDENT), newIncident({ isAnonymous: true })));
  });

  it('rejects any initial status other than submitted', async () => {
    await assertFails(create(as(STUDENT), newIncident({ status: 'resolved' })));
  });

  it('rejects filing on behalf of someone else', async () => {
    await assertFails(create(as(OTHER), newIncident()));
  });

  it('enforces field validation', async () => {
    const ctx = as(STUDENT);
    await assertFails(create(ctx, newIncident({ title: 'Leak' })));
    await assertFails(create(ctx, newIncident({ description: 'short' })));
    await assertFails(create(ctx, newIncident({ category: 'aliens' })));
    await assertFails(create(ctx, newIncident({ photoUrls: ['a', 'b', 'c', 'd'] })));
    await assertFails(create(ctx, newIncident({ extra: true })));
    await assertFails(create(ctx, newIncident({ createdAt: new Date(2020, 1, 1) })));
  });
});

// ---------- incidents: student edits and deletes ----------

describe('incidents: reporter edits', () => {
  it('lets the reporter edit while submitted', async () => {
    await seed();
    await assertSucceeds(
      updateDoc(doc(db(as(STUDENT)), 'incidents', 'inc1'), {
        title: 'Leaking tap, getting worse',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('prevents a student from changing the status', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(db(as(STUDENT)), 'incidents', 'inc1'), {
        status: 'resolved',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('prevents changing the reporter', async () => {
    await seed();
    await assertFails(
      updateDoc(doc(db(as(STUDENT)), 'incidents', 'inc1'), {
        reporterId: OTHER.uid,
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it("prevents editing someone else's report", async () => {
    await seed();
    await assertFails(
      updateDoc(doc(db(as(OTHER)), 'incidents', 'inc1'), {
        title: 'Hijacked title',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('blocks edits once the status has left submitted', async () => {
    await seed({ status: 'under_review' });
    await assertFails(
      updateDoc(doc(db(as(STUDENT)), 'incidents', 'inc1'), {
        title: 'Too late to edit',
        updatedAt: serverTimestamp(),
      }),
    );
  });

  it('lets the reporter delete only while submitted', async () => {
    await seed();
    await assertSucceeds(deleteDoc(doc(db(as(STUDENT)), 'incidents', 'inc1')));

    await seed({ status: 'in_progress' });
    await assertFails(deleteDoc(doc(db(as(STUDENT)), 'incidents', 'inc1')));
  });
});

// ---------- incidents: staff ----------

describe('incidents: staff status updates', () => {
  it('lets staff update status with a history entry in one batch', async () => {
    await seed();
    await assertSucceeds(
      statusBatch(as(STAFF), STAFF, 'submitted', 'under_review', 'Looking').commit(),
    );
  });

  it('rejects transitions outside the lifecycle', async () => {
    await seed();
    await assertFails(
      statusBatch(as(STAFF), STAFF, 'submitted', 'resolved').commit(),
    );
  });

  it('denies students the same batch', async () => {
    await seed();
    await assertFails(
      statusBatch(as(STUDENT), STUDENT, 'submitted', 'under_review').commit(),
    );
  });

  it('rejects a history entry that does not match a real status change', async () => {
    await seed();
    const ref = doc(collection(db(as(STAFF)), 'incidents', 'inc1', 'statusHistory'));
    await assertFails(
      setDoc(ref, {
        from: 'submitted', to: 'under_review', note: '',
        changedBy: STAFF.uid, at: serverTimestamp(),
      }),
    );
  });

  it('rejects a history entry attributed to someone else', async () => {
    await seed();
    const batch = statusBatch(as(STAFF), { uid: 'someone-else' },
      'submitted', 'under_review');
    await assertFails(batch.commit());
  });

  it('keeps history immutable', async () => {
    await seed();
    await statusBatch(as(STAFF), STAFF, 'submitted', 'under_review').commit();
    let eventId;
    await env.withSecurityRulesDisabled(async (ctx) => {
      const { getDocs } = await import('firebase/firestore');
      const snap = await getDocs(
        collection(ctx.firestore(), 'incidents', 'inc1', 'statusHistory'),
      );
      eventId = snap.docs[0].id;
    });
    const eventRef = doc(db(as(STAFF)), 'incidents', 'inc1', 'statusHistory', eventId);
    await assertFails(updateDoc(eventRef, { note: 'rewritten' }));
    await assertFails(deleteDoc(eventRef));
    await assertSucceeds(getDoc(doc(db(as(STUDENT)), 'incidents', 'inc1',
      'statusHistory', eventId)));
  });

  it('lets staff delete any incident', async () => {
    await seed({ status: 'in_progress' });
    await assertSucceeds(deleteDoc(doc(db(as(STAFF)), 'incidents', 'inc1')));
  });
});

// ---------- Storage ----------

describe('storage: incident photos', () => {
  const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);

  function upload(ctx, path, { contentType = 'image/jpeg', ownerUid, bytes = jpeg } = {}) {
    const meta = { contentType };
    if (ownerUid) meta.customMetadata = { ownerUid };
    return uploadBytes(ref(ctx.storage(), path), bytes, meta);
  }

  it('lets a verified user upload a photo for a new incident', async () => {
    await assertSucceeds(
      upload(as(STUDENT), 'incident_photos/new1/a.jpg', { ownerUid: STUDENT.uid }),
    );
  });

  it('requires the file to be tagged with the uploader', async () => {
    await assertFails(upload(as(STUDENT), 'incident_photos/new1/a.jpg'));
    await assertFails(
      upload(as(STUDENT), 'incident_photos/new1/a.jpg', { ownerUid: OTHER.uid }),
    );
  });

  it('accepts images only, under 5 MB', async () => {
    await assertFails(
      upload(as(STUDENT), 'incident_photos/new1/a.pdf', {
        ownerUid: STUDENT.uid, contentType: 'application/pdf',
      }),
    );
    await assertFails(
      upload(as(STUDENT), 'incident_photos/new1/big.jpg', {
        ownerUid: STUDENT.uid, bytes: new Uint8Array(5 * 1024 * 1024 + 1),
      }),
    );
  });

  it("blocks uploads into someone else's existing incident", async () => {
    await seed();
    await assertFails(
      upload(as(OTHER), 'incident_photos/inc1/x.jpg', { ownerUid: OTHER.uid }),
    );
    await assertSucceeds(
      upload(as(STUDENT), 'incident_photos/inc1/y.jpg', { ownerUid: STUDENT.uid }),
    );
  });

  it('denies unverified users', async () => {
    await assertFails(
      upload(as(STUDENT, { verified: false }), 'incident_photos/new1/a.jpg', {
        ownerUid: STUDENT.uid,
      }),
    );
  });

  it('allows no other paths', async () => {
    await assertFails(
      upload(as(STUDENT), 'avatars/a.jpg', { ownerUid: STUDENT.uid }),
    );
  });
});
