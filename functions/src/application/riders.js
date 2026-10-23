'use strict';
const d = require('../domain/domain');
const riderContact = require('../domain/rider-contact');

function createRiderHandlers({ db, hasRole, FieldValue, FieldPath, Filter }) {
  const listRiders = async (req) => {
    const profile = await db.doc('users/' + req.auth.uid).get();
    if (!hasRole(profile.data(), 'admin') || profile.data()?.deletionPending)
      d.fail('Administrator access required.', 'permission-denied');
    let query = db
      .collection('users')
      .where(
        Filter.or(
          Filter.where('role', '==', 'rider'),
          Filter.where('roles', 'array-contains', 'rider'),
        ),
      )
      .orderBy(FieldPath.documentId())
      .limit(101);
    if (req.data?.after != null) query = query.startAfter(d.id(req.data.after));
    const result = await query.get(),
      page = result.docs.slice(0, 100);
    return {
      riders: page.map((s) => ({
        uid: s.id,
        name: typeof s.data().name === 'string' ? s.data().name.slice(0, 160) : 'Rider',
      })),
      next: result.size > 100 ? page.at(-1).id : null,
    };
  };

  const reviewRiderApplication = async (req) => {
    const reviewerId = req.auth.uid;
    const applicantId = d.id(req.data?.applicantId);
    const decision = d.text(req.data?.decision, 'decision', 20);
    if (!['approved', 'rejected'].includes(decision)) d.fail('Choose approve or reject.');

    const reviewerRef = db.collection('users').doc(reviewerId);
    const applicantRef = db.collection('users').doc(applicantId);
    const applicationRef = db.collection('rider_applications').doc(applicantId);

    return db.runTransaction(async (tx) => {
      const reviewer = await tx.get(reviewerRef);
      if (!hasRole(reviewer.data(), 'admin') || reviewer.data()?.deletionPending)
        d.fail('Administrator access required.', 'permission-denied');

      const application = await tx.get(applicationRef);
      const applicant = await tx.get(applicantRef);
      if (!application.exists || !applicant.exists || applicant.data()?.deletionPending)
        d.fail('Rider application no longer exists.', 'not-found');

      const currentStatus = application.data().status;
      if (currentStatus === decision) return { status: decision };
      if (currentStatus !== 'pending')
        d.fail('This application has already been reviewed.', 'failed-precondition');

      const contactPhone =
        decision === 'approved' ? riderContact.normalizePhone(application.data().phone) : null;
      const contactName =
        decision === 'approved'
          ? d.text(application.data().name || applicant.data().name, 'rider name', 160)
          : null;
      tx.update(applicationRef, {
        ...(contactPhone
          ? {
              phone: contactPhone,
              name: contactName,
              contactRevision: (application.data().contactRevision ?? 0) + 1,
            }
          : {}),
        status: decision,
        reviewedAt: FieldValue.serverTimestamp(),
        reviewedBy: reviewerId,
      });
      tx.create(db.collection('admin_audit').doc(), {
        actorId: reviewerId,
        action: 'rider_application_' + decision,
        target: applicantId,
        createdAt: FieldValue.serverTimestamp(),
      });
      if (decision === 'approved') {
        const profile = applicant.data();
        const roles = Array.from(
          new Set([
            ...(Array.isArray(profile.roles) ? profile.roles : [profile.role ?? 'customer']),
            'customer',
            'rider',
          ]),
        );
        const activeRole = roles.includes(profile.activeRole)
          ? profile.activeRole
          : roles.includes(profile.role)
            ? profile.role
            : 'customer';
        tx.update(applicantRef, { roles, activeRole, updatedAt: FieldValue.serverTimestamp() });
      }
      return { status: decision };
    });
  };

  return { listRiders, reviewRiderApplication };
}

module.exports = { createRiderHandlers };
