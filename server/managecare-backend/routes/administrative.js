
/**
 * Administrative Services API routes for ManageCare.
 * Implements the route table in docs/ADMINISTRATIVE_SERVICES_IMPLEMENTATION_SPEC.md
 * on top of the tables created by migration_042_administrative.sql and
 * migration_051_administrative_usage.sql.
 *
 * Mount (server.js):
 *   const administrativeRoutes = require('./routes/administrative');
 *   app.use('/api/administrative', authMiddleware, administrativeRoutes(pool));
 *
 * Rules every route follows:
 *  - Caller must be an active member of the business in the URL
 *    (requireBusinessMembership), the business must be an Administrative
 *    business, and its subscription must be active (one cached read).
 *  - Owners and admins see everything. Any other member sees only clients
 *    assigned to them and tasks / obligations assigned to them.
 *  - Every query filters on business_id.
 *  - Lists are paginated and fetch limit+1 rows to compute hasMore (no COUNT).
 *  - Plan limits are enforced with atomic conditional updates on the usage
 *    counters, in the same transaction as the insert, so two concurrent
 *    requests cannot both slip under a limit.
 *  - Sensitive client columns (portal_credentials, revenue_access_pin_hash)
 *    are never selected, so they cannot reach a response.
 *  - Every state change writes an activity-log row in the same transaction.
 */
const express = require('express');
const crypto = require('crypto');
const { asyncHandler, pagination } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');
const { getPrisma } = require('../src/lib/prisma-bridge');

// ── Settings ────────────────────────────────────────────────
const GRACE_DAYS = 7; // matches GRACE_PERIOD_DAYS in routes/subscriptions.js
const ENTITLEMENT_TTL_MS = 60 * 1000;
const ENTITLEMENT_CACHE_MAX = 5000;
const DASHBOARD_DUE_ITEMS = 10;
const FOLDER_LIST_CAP = 200;
const GIB = 1024n * 1024n * 1024n;
const DAY_MS = 24 * 60 * 60 * 1000;
const MANAGER_ROLES = ['owner', 'admin', 'sub_admin']; // spec: owner/admin-only actions

// Plan limits by tier. They are identical for the 3 / 6 / 12 month plans, so
// this is a five-row constant instead of 15 database rows. Mirrors
// lib/services/subscription_service.dart and the spec. null = unlimited.
const TIER_LIMITS = {
  tier1: { storageGb: 4, staffLimit: 4, clientLimit: 30, branchLimit: 0 },
  tier2: { storageGb: 10, staffLimit: 10, clientLimit: 75, branchLimit: 2 },
  tier3: { storageGb: 25, staffLimit: 20, clientLimit: 200, branchLimit: 5 },
  premium: { storageGb: 50, staffLimit: 50, clientLimit: 400, branchLimit: 10 },
  enterprise: { storageGb: null, staffLimit: null, clientLimit: null, branchLimit: null },
};
const PLAN_ID_RE = /^administrative_(tier1|tier2|tier3|premium|enterprise)_(3m|6m|12m)$/;

const TASK_STATUSES = ['assigned', 'in_progress', 'submitted', 'approved', 'rejected'];
const STORAGE_ACTIONS = ['replace_original', 'store_as_new_version'];

// ── Errors ──────────────────────────────────────────────────
class HttpError extends Error {
  constructor(statusCode, message, extra) {
    super(message);
    this.statusCode = statusCode;
    this.extra = extra;
  }
}

function limitError(limitType, limit, current) {
  return new HttpError(409, `Your plan's ${limitType} limit has been reached`, {
    limit_type: limitType,
    limit: limit == null ? null : Number(limit),
    current_usage: Number(current),
  });
}

function credentialEncryptionKey() {
  const configured = process.env.ADMIN_CREDENTIALS_ENCRYPTION_KEY || '';
  const key = /^[0-9a-f]{64}$/i.test(configured)
    ? Buffer.from(configured, 'hex')
    : Buffer.from(configured, 'base64');
  if (key.length !== 32) {
    throw new HttpError(503, 'Client credential encryption is not configured');
  }
  return key;
}

function encryptCredentials(credentials) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', credentialEncryptionKey(), iv);
  const ciphertext = Buffer.concat([
    cipher.update(JSON.stringify(credentials), 'utf8'),
    cipher.final(),
  ]);
  return {
    version: 1,
    iv: iv.toString('base64'),
    authTag: cipher.getAuthTag().toString('base64'),
    ciphertext: ciphertext.toString('base64'),
  };
}

function decryptCredentials(envelope) {
  if (!envelope || envelope.version !== 1) {
    throw new HttpError(409, 'Stored credentials must be re-entered to enable encrypted storage');
  }
  const decipher = crypto.createDecipheriv(
    'aes-256-gcm',
    credentialEncryptionKey(),
    Buffer.from(envelope.iv, 'base64'),
  );
  decipher.setAuthTag(Buffer.from(envelope.authTag, 'base64'));
  const plaintext = Buffer.concat([
    decipher.update(Buffer.from(envelope.ciphertext, 'base64')),
    decipher.final(),
  ]).toString('utf8');
  const parsed = JSON.parse(plaintext);
  if (!Array.isArray(parsed)) throw new HttpError(500, 'Stored credential data is invalid');
  return parsed;
}

function hashAccessPasscode(passcode, salt = crypto.randomBytes(16).toString('hex')) {
  const hash = crypto.scryptSync(passcode, salt, 32).toString('hex');
  return `scrypt$${salt}$${hash}`;
}

function verifyAccessPasscode(passcode, stored) {
  if (typeof stored !== 'string') return false;
  const [scheme, salt, hash] = stored.split('$');
  if (scheme !== 'scrypt' || !salt || !/^[0-9a-f]{64}$/i.test(hash || '')) return false;
  const actual = crypto.scryptSync(passcode, salt, 32);
  return crypto.timingSafeEqual(actual, Buffer.from(hash, 'hex'));
}

// ── Validation helpers ──────────────────────────────────────
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const isUuid = (v) => typeof v === 'string' && UUID_RE.test(v);

function requireUuid(value, name) {
  if (!isUuid(value)) throw new HttpError(400, `${name} must be a valid id`);
  return value;
}
function optionalUuid(value, name) {
  if (value === undefined || value === null || value === '') return null;
  return requireUuid(value, name);
}
function requireText(value, name, max = 200) {
  if (typeof value !== 'string' || value.trim() === '') throw new HttpError(400, `${name} is required`);
  const t = value.trim();
  if (t.length > max) throw new HttpError(400, `${name} must be at most ${max} characters`);
  return t;
}
function optionalText(value, name, max = 2000) {
  if (value === undefined || value === null || value === '') return null;
  return requireText(value, name, max);
}
function parseDateTime(value, name) {
  if (typeof value !== 'string') throw new HttpError(400, `${name} must be an ISO date or date-time`);
  const d = new Date(value);
  if (Number.isNaN(d.getTime()) || d.getUTCFullYear() < 2000 || d.getUTCFullYear() > 2100) {
    throw new HttpError(400, `${name} is not a valid date`);
  }
  return d;
}
function optionalDateTime(value, name) {
  if (value === undefined || value === null || value === '') return null;
  return parseDateTime(value, name);
}
function intInRange(value, name, min, max) {
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new HttpError(400, `${name} must be a whole number from ${min} to ${max}`);
  }
  return value;
}
function oneOf(value, allowed, name) {
  if (!allowed.includes(value)) throw new HttpError(400, `${name} must be one of: ${allowed.join(', ')}`);
  return value;
}

// ── Date math ───────────────────────────────────────────────
// Moves to the same time of day in a later month, on `day` (clamped to the
// last day of that month: day 31 in April becomes April 30).
function addMonthsOnDay(date, months, day) {
  const y = date.getUTCFullYear();
  const m = date.getUTCMonth() + months;
  const lastDay = new Date(Date.UTC(y, m + 1, 0)).getUTCDate();
  return new Date(Date.UTC(y, m, Math.min(day, lastDay),
    date.getUTCHours(), date.getUTCMinutes(), date.getUTCSeconds(), date.getUTCMilliseconds()));
}

// Spec "State Rules / Obligation completion".
//  trailing: next = completion time + interval_days
//  fixed:    anchored to the schedule; completing early (or late) does not move it.
//            With a fixed_day_of_month it is the next calendar occurrence after
//            the current due date (31 Jan + monthly -> 28/29 Feb, then 31 Mar);
//            without one it is the current due date + interval_days.
function computeNextDue(ob, completedAt) {
  if (ob.recurrenceType === 'trailing') {
    return new Date(completedAt.getTime() + ob.intervalDays * DAY_MS);
  }
  if (ob.fixedDayOfMonth) {
    const months = Math.max(1, Math.round(ob.intervalDays / 30.4375));
    return addMonthsOnDay(ob.nextDueAt, months, ob.fixedDayOfMonth);
  }
  return new Date(ob.nextDueAt.getTime() + ob.intervalDays * DAY_MS);
}

// ── Response shaping ────────────────────────────────────────
function paged(rows, { page, limit }) {
  const hasMore = rows.length > limit;
  return { data: hasMore ? rows.slice(0, limit) : rows, page, limit, hasMore };
}

// res.json cannot serialise BigInt.
const serializeDocument = (d) => {
  if (!d) return d;
  const fileSizeBytes = d.fileSizeBytes == null ? null : Number(d.fileSizeBytes);
  return {
    ...d,
    fileSizeBytes,
    file_name: d.fileName ?? null,
    file_url: d.fileUrl ?? null,
    file_size_bytes: fileSizeBytes,
    mime_type: d.mimeType ?? null,
    folder_name: d.folder?.name ?? null,
    version_number: d.versionNumber ?? null,
    document_id: d.documentId ?? null,
    created_at: d.createdAt ?? null,
  };
};
function serializeInvoice(invoice) {
  if (!invoice) return invoice;
  return {
    id: invoice.id,
    business_id: invoice.businessId,
    client_id: invoice.clientId,
    client_name: invoice.client?.name ?? invoice.clientName ?? null,
    invoice_number: invoice.invoiceNumber,
    status: invoice.status,
    currency: invoice.currency,
    issue_date: invoice.issueDate,
    due_date: invoice.dueDate,
    subtotal: Number(invoice.subtotal),
    tax_amount: Number(invoice.taxAmount),
    total_amount: Number(invoice.totalAmount),
    paid_amount: Number(invoice.paidAmount),
    notes: invoice.notes,
    sent_at: invoice.sentAt,
    paid_at: invoice.paidAt,
    created_at: invoice.createdAt,
    items: (invoice.items ?? []).map((item) => ({
      id: item.id,
      description: item.description,
      quantity: Number(item.quantity),
      unit_price: Number(item.unitPrice),
      line_total: Number(item.lineTotal),
    })),
  };
}
function serializeUsage(u) {
  return { storageBytes: u ? Number(u.storageBytes) : 0, clientCount: u ? u.clientCount : 0 };
}

// Allow-list of client columns. portalCredentials and revenueAccessPinHash are
// deliberately absent: they cannot be returned by any route.
const CLIENT_SELECT = {
  id: true, businessId: true, name: true, companyName: true, location: true,
  contactAddress: true, archivedAt: true, createdAt: true, updatedAt: true,
};

// ── Access helpers ──────────────────────────────────────────
function isManager(req) {
  const m = req.businessMembership;
  if (!m) return false;
  return Boolean(m.is_owner) || MANAGER_ROLES.includes(String(m.role || '').trim().toLowerCase());
}
function requireManager(req, _res, next) {
  if (!isManager(req)) return next(new HttpError(403, 'Owner or admin access required'));
  next();
}
const me = (req) => req.user.id;

// ── Entitlement: one cached read of the business row ────────
const entitlementCache = new Map(); // businessId -> { value, at }

function invalidateEntitlement(businessId) {
  if (businessId) entitlementCache.delete(businessId);
  else entitlementCache.clear();
}

// The business row is already where payments write subscription state
// (syncBusinessSubscription in routes/subscriptions.js), so no new table is read.
async function loadEntitlement(prisma, businessId) {
  const biz = await prisma.businesses.findUnique({
    where: { id: businessId },
    select: {
      business_type: true, subscription_family: true, subscription_plan: true,
      subscription_tier: true, subscription_end_date: true, is_subscription_active: true,
      is_active: true, is_deleted: true, is_restricted: true,
    },
  });
  if (!biz || biz.is_deleted || biz.is_active === false) return { error: [404, 'Business not found'] };
  if (biz.business_type !== 'administrative' && biz.subscription_family !== 'administrative') {
    return { error: [403, 'Administrative Services is not enabled for this business'] };
  }
  if (biz.is_restricted) return { error: [403, 'This business is restricted'] };

  const planMatch = PLAN_ID_RE.exec(String(biz.subscription_plan || ''));
  const tier = planMatch ? planMatch[1] : String(biz.subscription_tier || '').toLowerCase();
  const limits = TIER_LIMITS[tier];
  const end = biz.subscription_end_date;
  const live = biz.is_subscription_active === true && (!end || end.getTime() + GRACE_DAYS * DAY_MS > Date.now());
  if (!limits || !live) return { error: [402, 'No active administrative subscription for this business'] };
  return { value: { tier, expiresAt: end, ...limits } };
}

async function getEntitlement(prisma, businessId) {
  const now = Date.now();
  const hit = entitlementCache.get(businessId);
  let result;
  if (hit && now - hit.at < ENTITLEMENT_TTL_MS) {
    result = hit.result;
  } else {
    result = await loadEntitlement(prisma, businessId);
    if (entitlementCache.size >= ENTITLEMENT_CACHE_MAX) entitlementCache.clear();
    entitlementCache.set(businessId, { result, at: now });
  }
  // A cached entry must never outlive the subscription itself.
  const v = result.value;
  if (v && v.expiresAt && v.expiresAt.getTime() + GRACE_DAYS * DAY_MS <= now) {
    return { error: [402, 'No active administrative subscription for this business'] };
  }
  return result;
}

// ── Usage counters (atomic) ─────────────────────────────────
async function ensureUsageRow(tx, businessId) {
  await tx.administrativeUsage.upsert({ where: { businessId }, create: { businessId }, update: {} });
}

// Takes one client slot, or throws a 409 with limit_type / limit / current_usage.
async function takeClientSlot(tx, businessId, limit) {
  await ensureUsageRow(tx, businessId);
  const r = await tx.administrativeUsage.updateMany({
    where: limit == null ? { businessId } : { businessId, clientCount: { lt: limit } },
    data: { clientCount: { increment: 1 } },
  });
  if (r.count === 0) {
    const u = await tx.administrativeUsage.findUnique({ where: { businessId } });
    throw limitError('clients', limit, u ? u.clientCount : 0);
  }
}

async function releaseClientSlot(tx, businessId) {
  await tx.administrativeUsage.updateMany({
    where: { businessId, clientCount: { gt: 0 } },
    data: { clientCount: { decrement: 1 } },
  });
}

async function takeStorage(tx, businessId, bytes, limitGb) {
  if (bytes === 0n) return;
  await ensureUsageRow(tx, businessId);
  const where = limitGb == null
    ? { businessId }
    : { businessId, storageBytes: { lte: BigInt(limitGb) * GIB - bytes } };
  const r = await tx.administrativeUsage.updateMany({ where, data: { storageBytes: { increment: bytes } } });
  if (r.count === 0) {
    const u = await tx.administrativeUsage.findUnique({ where: { businessId } });
    throw limitError('storage', limitGb == null ? null : BigInt(limitGb) * GIB, u ? u.storageBytes : 0n);
  }
}

// ── Audit log ───────────────────────────────────────────────
// Written in the same transaction as the change. Never put passwords,
// passcodes, tokens or document content in `metadata`.
function logActivity(tx, { businessId, clientId, actorId, action, entityType, entityId, metadata }) {
  return tx.administrativeActivityLog.create({
    data: {
      businessId, clientId: clientId || null, actorId: actorId || null,
      action, entityType, entityId: entityId || null, metadata: metadata || {},
    },
  });
}

// ── Router ──────────────────────────────────────────────────
module.exports = function administrativeRoutes(pool, { sendMail } = {}) {
  // Created inside the factory so calling it twice does not stack handlers.
  const router = express.Router();

  for (const name of ['businessId', 'clientId', 'workerId', 'documentId', 'taskId', 'obligationId']) {
    router.param(name, (_req, _res, next, value) => {
      if (!isUuid(value)) return next(new HttpError(400, `${name} must be a valid id`));
      next();
    });
  }

  // 1. membership  2. administrative business + active subscription (cached)
  router.use('/:businessId', requireBusinessMembership(pool));
  router.use('/:businessId', asyncHandler(async (req, _res, next) => {
    const prisma = await getPrisma();
    const { value, error } = await getEntitlement(prisma, req.params.businessId);
    if (error) throw new HttpError(error[0], error[1]);
    req.entitlement = value;
    next();
  }));

  // Managers see every client; others only clients assigned to them.
  // Returns 404 (not 403) so the existence of other clients is not revealed.
  async function loadClient(prisma, req, clientId, { allowArchived = false } = {}) {
    const where = { id: clientId, businessId: req.params.businessId };
    if (!allowArchived) where.archivedAt = null;
    if (!isManager(req)) where.workers = { some: { workerId: me(req) } };
    const client = await prisma.administrativeClient.findFirst({ where, select: CLIENT_SELECT });
    if (!client) throw new HttpError(404, 'Client not found');
    return client;
  }

  async function requireWorkerInBusiness(prisma, businessId, workerId) {
    const w = await prisma.workers.findFirst({
      where: { id: workerId, business_id: businessId, is_active: true }, select: { id: true },
    });
    if (!w) throw new HttpError(404, 'Worker not found in this business');
  }

  // ── Dashboard: counts and the next few due items, never full lists ──
  router.get('/:businessId/dashboard', asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId } = req.params;
    const manager = isManager(req);
    const assignee = manager ? null : me(req); // workers see only their own work

    const [usage, staffCount, clientCount, financialTotals, obligationBuckets, taskBuckets, dueSoon] = await Promise.all([
      prisma.administrativeUsage.findUnique({ where: { businessId } }),
      prisma.workers.count({ where: { business_id: businessId, is_active: true } }),
      prisma.administrativeClient.count({ where: { businessId, archivedAt: null } }),
      prisma.administrativeFinancialEntry.groupBy({
        by: ['entryType'],
        where: { businessId },
        _sum: { amount: true },
      }),
      prisma.$queryRaw`
        SELECT
          COUNT(*) FILTER (WHERE next_due_at < now())::int AS "overdue",
          COUNT(*) FILTER (WHERE next_due_at >= now() AND next_due_at < now() + interval '1 day')::int  AS "dueWithin24h",
          COUNT(*) FILTER (WHERE next_due_at >= now() AND next_due_at < now() + interval '3 days')::int AS "dueWithin3d",
          COUNT(*) FILTER (WHERE next_due_at >= now() AND next_due_at < now() + interval '7 days')::int AS "dueWithin7d"
        FROM administrative_obligations
        WHERE business_id = ${businessId}::uuid AND is_active
          AND next_due_at < now() + interval '7 days'
          AND (${assignee}::uuid IS NULL OR assigned_to = ${assignee}::uuid)`,
      prisma.$queryRaw`
        SELECT
          COUNT(*) FILTER (WHERE status = 'submitted')::int AS "awaitingReview",
          COUNT(*) FILTER (WHERE status IN ('assigned','in_progress') AND due_at < now())::int AS "overdue",
          COUNT(*) FILTER (WHERE status IN ('assigned','in_progress') AND due_at >= now()
                           AND due_at < now() + interval '3 days')::int AS "dueSoon"
        FROM administrative_tasks
        WHERE business_id = ${businessId}::uuid AND status <> 'approved'
          AND (${assignee}::uuid IS NULL OR assigned_to = ${assignee}::uuid)`,
      prisma.administrativeObligation.findMany({
        where: { businessId, isActive: true, ...(assignee ? { assignedTo: assignee } : {}) },
        orderBy: { nextDueAt: 'asc' },
        take: DASHBOARD_DUE_ITEMS,
        select: { id: true, clientId: true, title: true, nextDueAt: true, recurrenceType: true, assignedTo: true },
      }),
    ]);

    const u = serializeUsage(usage);
    const e = req.entitlement;
    const financial = Object.fromEntries(financialTotals.map((row) => [
      row.entryType,
      Number(row._sum.amount ?? 0),
    ]));
    res.json({
      data: {
        subscription: { tier: e.tier, expiresAt: e.expiresAt },
        metrics: {
          revenue: financial.revenue ?? 0,
          expenses: financial.expense ?? 0,
          clients: clientCount,
          staff: staffCount,
        },
        usage: {
          storage: { usedBytes: u.storageBytes, limitGb: e.storageGb },
          clients: { used: u.clientCount, limit: e.clientLimit },
          staff: { used: staffCount, limit: e.staffLimit },
        },
        obligations: { ...obligationBuckets[0], next: dueSoon },
        tasks: taskBuckets[0],
      },
    });
  }));

  // ── Clients ──────────────────────────────────────────────
  router.get('/:businessId/clients', pagination, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId } = req.params;
    const where = { businessId };
    const status = req.query.status === undefined ? 'active' : oneOf(String(req.query.status), ['active', 'archived', 'all'], 'status');
    if (status === 'active') where.archivedAt = null;
    if (status === 'archived') where.archivedAt = { not: null };
    if (!isManager(req)) where.workers = { some: { workerId: me(req) } };
    else if (req.query.workerId !== undefined) where.workers = { some: { workerId: requireUuid(String(req.query.workerId), 'workerId') } };
    if (typeof req.query.q === 'string' && req.query.q.trim()) {
      const q = req.query.q.trim().slice(0, 100);
      where.OR = [
        { name: { contains: q, mode: 'insensitive' } },
        { companyName: { contains: q, mode: 'insensitive' } },
        { location: { contains: q, mode: 'insensitive' } },
      ];
    }
    if (typeof req.query.location === 'string' && req.query.location.trim()) {
      where.location = { contains: req.query.location.trim().slice(0, 100), mode: 'insensitive' };
    }
    const rows = await prisma.administrativeClient.findMany({
      where,
      select: { ...CLIENT_SELECT, _count: { select: { workers: true, documents: true } } },
      orderBy: { name: 'asc' },
      take: req.pagination.limit + 1,
      skip: req.pagination.offset,
    });
    res.json(paged(rows, req.pagination));
  }));

  router.get('/:businessId/staffing', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId } = req.params;
    const workers = await prisma.workers.findMany({
      where: { business_id: businessId },
      select: { id: true, full_name: true, role: true, is_active: true },
      orderBy: { full_name: 'asc' },
    });
    const workerIds = workers.map((worker) => worker.id);
    if (workerIds.length === 0) return res.json({ data: [] });
    const [links, tasks] = await Promise.all([
      prisma.administrativeClientWorker.findMany({
        where: { workerId: { in: workerIds } },
        select: { workerId: true, clientId: true },
      }),
      prisma.administrativeTask.findMany({
        where: {
          businessId,
          assignedTo: { in: workerIds },
          status: { in: ['assigned', 'in_progress', 'submitted'] },
        },
        select: { assignedTo: true },
      }),
    ]);
    const clientIdsByWorker = new Map();
    for (const link of links) {
      const ids = clientIdsByWorker.get(link.workerId) || new Set();
      ids.add(link.clientId);
      clientIdsByWorker.set(link.workerId, ids);
    }
    const openTasksByWorker = new Map();
    for (const task of tasks) {
      if (task.assignedTo) {
        openTasksByWorker.set(task.assignedTo, (openTasksByWorker.get(task.assignedTo) || 0) + 1);
      }
    }
    res.json({ data: workers.map((worker) => ({
      ...worker,
      assigned_client_ids: [...(clientIdsByWorker.get(worker.id) || [])],
      assigned_client_count: (clientIdsByWorker.get(worker.id) || new Set()).size,
      open_task_count: openTasksByWorker.get(worker.id) || 0,
    })) });
  }));

  router.get('/:businessId/calendar', asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId } = req.params;
    const from = parseDateTime(String(req.query.from ?? ''), 'from');
    const to = parseDateTime(String(req.query.to ?? ''), 'to');
    if (to <= from) throw new HttpError(400, 'to must be after from');
    const workerScope = isManager(req) ? {} : { assignedTo: me(req) };
    const eventScope = isManager(req) ? {} : { createdBy: me(req) };
    const [tasks, obligations, events] = await Promise.all([
      prisma.administrativeTask.findMany({
        where: { businessId, dueAt: { gte: from, lt: to }, ...workerScope },
        select: {
          id: true, title: true, dueAt: true, status: true, clientId: true,
          client: { select: { name: true } },
        },
        orderBy: { dueAt: 'asc' },
        take: 500,
      }),
      prisma.administrativeObligation.findMany({
        where: {
          businessId, isActive: true, nextDueAt: { gte: from, lt: to },
          ...workerScope,
        },
        select: {
          id: true, title: true, nextDueAt: true, clientId: true,
          client: { select: { name: true } },
        },
        orderBy: { nextDueAt: 'asc' },
        take: 500,
      }),
      prisma.administrativeCalendarEvent.findMany({
        where: { businessId, startsAt: { gte: from, lt: to }, ...eventScope },
        select: {
          id: true, title: true, description: true, startsAt: true, clientId: true,
          client: { select: { name: true } },
        },
        orderBy: { startsAt: 'asc' },
        take: 500,
      }),
    ]);
    res.json({ data: [
      ...tasks.map((task) => ({
        event_type: 'task', id: task.id, title: task.title, starts_at: task.dueAt,
        status: task.status, client_id: task.clientId, client_name: task.client?.name,
      })),
      ...obligations.map((obligation) => ({
        event_type: 'obligation', id: obligation.id, title: obligation.title,
        starts_at: obligation.nextDueAt, client_id: obligation.clientId,
        client_name: obligation.client?.name,
      })),
      ...events.map((event) => ({
        event_type: 'event', id: event.id, title: event.title,
        description: event.description, starts_at: event.startsAt,
        client_id: event.clientId, client_name: event.client?.name,
      })),
    ] });
  }));

  router.post('/:businessId/calendar-events', asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId } = req.params;
    const b = req.body || {};
    const clientId = optionalUuid(b.clientId, 'clientId');
    if (clientId) await loadClient(prisma, req, clientId);
    const created = await prisma.$transaction(async (tx) => {
      const event = await tx.administrativeCalendarEvent.create({
        data: {
          businessId,
          clientId,
          title: requireText(b.title, 'title'),
          description: optionalText(b.description, 'description', 2000),
          startsAt: parseDateTime(b.startsAt, 'startsAt'),
          createdBy: me(req),
        },
      });
      await logActivity(tx, {
        businessId, clientId, actorId: me(req), action: 'calendar_event.created',
        entityType: 'calendar_event', entityId: event.id,
      });
      return event;
    });
    res.status(201).json({ data: created });
  }));

  router.post('/:businessId/clients', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId } = req.params;
    const b = req.body || {};
    const data = {
      name: requireText(b.name, 'name'),
      companyName: optionalText(b.companyName, 'companyName'),
      location: optionalText(b.location, 'location'),
      contactAddress: optionalText(b.contactAddress, 'contactAddress', 500),
    };
    const client = await prisma.$transaction(async (tx) => {
      await takeClientSlot(tx, businessId, req.entitlement.clientLimit);
      const created = await tx.administrativeClient.create({
        data: { businessId, createdBy: me(req), ...data }, select: CLIENT_SELECT,
      });
      await logActivity(tx, { businessId, clientId: created.id, actorId: me(req), action: 'client.created', entityType: 'client', entityId: created.id });
      return created;
    });
    res.status(201).json({ data: client });
  }));

  router.get('/:businessId/clients/:clientId', asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const client = await loadClient(prisma, req, req.params.clientId, { allowArchived: true });
    const workers = await prisma.administrativeClientWorker.findMany({
      where: { clientId: client.id },
      select: {
        workerId: true,
        assignedAt: true,
        worker: { select: { full_name: true, role: true, is_active: true } },
      },
    });
    res.json({ data: { ...client, workers } });
  }));

  router.get('/:businessId/clients/:clientId/security', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, clientId } = req.params;
    await loadClient(prisma, req, clientId, { allowArchived: true });
    const client = await prisma.administrativeClient.findFirst({
      where: { id: clientId, businessId },
      select: { revenueAccessPinHash: true, portalCredentials: true },
    });
    const credentials = client.portalCredentials;
    res.json({ data: {
      hasPasscode: Boolean(client.revenueAccessPinHash),
      hasCredentials: Boolean(credentials && credentials.version === 1 && credentials.ciphertext),
    } });
  }));

  router.put('/:businessId/clients/:clientId/security/passcode', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, clientId } = req.params;
    await loadClient(prisma, req, clientId, { allowArchived: true });
    const passcode = String(crypto.randomInt(0, 1000000)).padStart(6, '0');
    await prisma.$transaction(async (tx) => {
      await tx.administrativeClient.updateMany({
        where: { id: clientId, businessId },
        data: { revenueAccessPinHash: hashAccessPasscode(passcode), updatedAt: new Date() },
      });
      await logActivity(tx, {
        businessId, clientId, actorId: me(req), action: 'client.passcode_rotated',
        entityType: 'client', entityId: clientId,
      });
    });
    res.json({ data: { passcode } });
  }));

  router.put('/:businessId/clients/:clientId/credentials', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, clientId } = req.params;
    await loadClient(prisma, req, clientId, { allowArchived: true });
    const input = (req.body || {}).credentials;
    if (!Array.isArray(input) || input.length > 100) {
      throw new HttpError(400, 'credentials must be an array with at most 100 entries');
    }
    const credentials = input.map((item, index) => ({
      id: optionalText(item.id, `credentials[${index}].id`, 80) || crypto.randomUUID(),
      portal: requireText(item.portal, `credentials[${index}].portal`, 120),
      username: requireText(item.username, `credentials[${index}].username`, 254),
      password: requireText(item.password, `credentials[${index}].password`, 1000),
      notes: optionalText(item.notes, `credentials[${index}].notes`, 1000),
    }));
    const encrypted = encryptCredentials(credentials);
    await prisma.$transaction(async (tx) => {
      await tx.administrativeClient.updateMany({
        where: { id: clientId, businessId },
        data: { portalCredentials: encrypted, updatedAt: new Date() },
      });
      await logActivity(tx, {
        businessId, clientId, actorId: me(req), action: 'client.credentials_updated',
        entityType: 'client', entityId: clientId,
        metadata: { credentialCount: credentials.length },
      });
    });
    res.json({ data: { saved: true, credentialCount: credentials.length } });
  }));

  router.post('/:businessId/clients/:clientId/credentials/reveal', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, clientId } = req.params;
    await loadClient(prisma, req, clientId, { allowArchived: true });
    const passcode = requireText((req.body || {}).passcode, 'passcode', 6);
    if (!/^\d{6}$/.test(passcode)) throw new HttpError(400, 'passcode must contain exactly six digits');
    const client = await prisma.administrativeClient.findFirst({
      where: { id: clientId, businessId },
      select: { revenueAccessPinHash: true, portalCredentials: true },
    });
    if (!verifyAccessPasscode(passcode, client.revenueAccessPinHash)) {
      await logActivity(prisma, {
        businessId, clientId, actorId: me(req), action: 'client.credentials_reveal_failed',
        entityType: 'client', entityId: clientId,
      });
      throw new HttpError(403, 'Passcode is incorrect');
    }
    const credentials = Array.isArray(client.portalCredentials) && client.portalCredentials.length === 0
      ? []
      : decryptCredentials(client.portalCredentials);
    await logActivity(prisma, {
      businessId, clientId, actorId: me(req), action: 'client.credentials_revealed',
      entityType: 'client', entityId: clientId,
      metadata: { credentialCount: credentials.length },
    });
    res.json({ data: { credentials } });
  }));

  router.patch('/:businessId/clients/:clientId', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, clientId } = req.params;
    const b = req.body || {};
    const data = {};
    if (b.name !== undefined) data.name = requireText(b.name, 'name');
    if (b.companyName !== undefined) data.companyName = optionalText(b.companyName, 'companyName');
    if (b.location !== undefined) data.location = optionalText(b.location, 'location');
    if (b.contactAddress !== undefined) data.contactAddress = optionalText(b.contactAddress, 'contactAddress', 500);
    if (Object.keys(data).length === 0) throw new HttpError(400, 'No valid fields supplied');
    const client = await prisma.$transaction(async (tx) => {
      const r = await tx.administrativeClient.updateMany({ where: { id: clientId, businessId }, data: { ...data, updatedAt: new Date() } });
      if (r.count === 0) throw new HttpError(404, 'Client not found');
      await logActivity(tx, { businessId, clientId, actorId: me(req), action: 'client.updated', entityType: 'client', entityId: clientId, metadata: { fields: Object.keys(data) } });
      return tx.administrativeClient.findFirst({ where: { id: clientId, businessId }, select: CLIENT_SELECT });
    });
    res.json({ data: client });
  }));

  // DELETE archives (soft). Documents, tasks and obligations are kept, and the
  // client stops counting against the plan.
  router.delete('/:businessId/clients/:clientId', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, clientId } = req.params;
    await prisma.$transaction(async (tx) => {
      const r = await tx.administrativeClient.updateMany({
        where: { id: clientId, businessId, archivedAt: null }, data: { archivedAt: new Date() },
      });
      if (r.count === 0) throw new HttpError(404, 'Client not found or already archived');
      await releaseClientSlot(tx, businessId);
      await logActivity(tx, { businessId, clientId, actorId: me(req), action: 'client.archived', entityType: 'client', entityId: clientId });
    });
    res.json({ data: { id: clientId, archived: true } });
  }));

  router.post('/:businessId/clients/:clientId/restore', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, clientId } = req.params;
    await prisma.$transaction(async (tx) => {
      const r = await tx.administrativeClient.updateMany({
        where: { id: clientId, businessId, archivedAt: { not: null } }, data: { archivedAt: null },
      });
      if (r.count === 0) throw new HttpError(404, 'Archived client not found');
      await takeClientSlot(tx, businessId, req.entitlement.clientLimit); // rolls the restore back if over limit
      await logActivity(tx, { businessId, clientId, actorId: me(req), action: 'client.restored', entityType: 'client', entityId: clientId });
    });
    res.json({ data: { id: clientId, archived: false } });
  }));

  // ── Worker assignment (owner / admin) ────────────────────
  router.put('/:businessId/clients/:clientId/workers/:workerId', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, clientId, workerId } = req.params;
    await loadClient(prisma, req, clientId);
    await requireWorkerInBusiness(prisma, businessId, workerId);
    await prisma.$transaction(async (tx) => {
      await tx.administrativeClientWorker.upsert({
        where: { clientId_workerId: { clientId, workerId } },
        create: { clientId, workerId, assignedBy: me(req) },
        update: {},
      });
      await logActivity(tx, { businessId, clientId, actorId: me(req), action: 'client.worker_assigned', entityType: 'client', entityId: clientId, metadata: { workerId } });
    });
    res.json({ data: { clientId, workerId, assigned: true } });
  }));

  router.delete('/:businessId/clients/:clientId/workers/:workerId', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, clientId, workerId } = req.params;
    await loadClient(prisma, req, clientId, { allowArchived: true });
    const removed = await prisma.$transaction(async (tx) => {
      const r = await tx.administrativeClientWorker.deleteMany({ where: { clientId, workerId } });
      if (r.count > 0) {
        await logActivity(tx, { businessId, clientId, actorId: me(req), action: 'client.worker_unassigned', entityType: 'client', entityId: clientId, metadata: { workerId } });
      }
      return r.count;
    });
    res.json({ data: { clientId, workerId, assigned: false, removed } });
  }));

  // ── Folders ──────────────────────────────────────────────
  router.get('/:businessId/clients/:clientId/folders', asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, clientId } = req.params;
    await loadClient(prisma, req, clientId, { allowArchived: true });
    const rows = await prisma.administrativeDocumentFolder.findMany({
      where: { businessId, clientId }, orderBy: { name: 'asc' }, take: FOLDER_LIST_CAP + 1,
      select: { id: true, clientId: true, name: true, createdAt: true },
    });
    res.json({ data: rows.slice(0, FOLDER_LIST_CAP), hasMore: rows.length > FOLDER_LIST_CAP });
  }));

  router.post('/:businessId/clients/:clientId/folders', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, clientId } = req.params;
    const name = requireText((req.body || {}).name, 'name', 120);
    await loadClient(prisma, req, clientId);
    const folder = await prisma.$transaction(async (tx) => {
      const f = await tx.administrativeDocumentFolder.create({
        data: { businessId, clientId, name, createdBy: me(req) },
        select: { id: true, clientId: true, name: true, createdAt: true },
      });
      await logActivity(tx, { businessId, clientId, actorId: me(req), action: 'folder.created', entityType: 'folder', entityId: f.id });
      return f;
    });
    res.status(201).json({ data: folder });
  }));

  // ── Documents (metadata; the file itself goes through /api/upload) ──
  router.get('/:businessId/clients/:clientId/documents', pagination, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, clientId } = req.params;
    await loadClient(prisma, req, clientId, { allowArchived: true });
    const where = { businessId, clientId };
    if (req.query.folderId !== undefined) {
      where.folderId = req.query.folderId === 'none' ? null : requireUuid(String(req.query.folderId), 'folderId');
    }
    if (req.query.status !== undefined) where.status = oneOf(String(req.query.status), ['stored', ...TASK_STATUSES], 'status');
    if (typeof req.query.q === 'string' && req.query.q.trim()) {
      where.fileName = { contains: req.query.q.trim().slice(0, 100), mode: 'insensitive' };
    }
    const rows = await prisma.administrativeDocument.findMany({
      where,
      include: { folder: { select: { name: true } } },
      orderBy: { createdAt: 'desc' },
      take: req.pagination.limit + 1,
      skip: req.pagination.offset,
    });
    const out = paged(rows, req.pagination);
    out.data = out.data.map(serializeDocument);
    res.json(out);
  }));

  router.post('/:businessId/clients/:clientId/documents', asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, clientId } = req.params;
    const b = req.body || {};
    const fileName = requireText(b.fileName, 'fileName', 255);
    const fileUrl = requireText(b.fileUrl, 'fileUrl', 2048);
    const mimeType = optionalText(b.mimeType, 'mimeType', 127);
    const size = b.fileSizeBytes === undefined || b.fileSizeBytes === null
      ? 0 : intInRange(b.fileSizeBytes, 'fileSizeBytes', 0, Number.MAX_SAFE_INTEGER);
    const folderId = optionalUuid(b.folderId, 'folderId');

    await loadClient(prisma, req, clientId);
    if (folderId) {
      const folder = await prisma.administrativeDocumentFolder.findFirst({ where: { id: folderId, clientId, businessId }, select: { id: true } });
      if (!folder) throw new HttpError(404, 'Folder not found for this client');
    }
    const doc = await prisma.$transaction(async (tx) => {
      await takeStorage(tx, businessId, BigInt(size), req.entitlement.storageGb);
      const d = await tx.administrativeDocument.create({
        data: { businessId, clientId, folderId, fileName, fileUrl, fileSizeBytes: BigInt(size), mimeType, uploadedBy: me(req) },
      });
      await logActivity(tx, { businessId, clientId, actorId: me(req), action: 'document.uploaded', entityType: 'document', entityId: d.id, metadata: { fileName, size } });
      return d;
    });
    res.status(201).json({ data: serializeDocument(doc) });
  }));

  router.get('/:businessId/documents/:documentId/versions', asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, documentId } = req.params;
    const document = await prisma.administrativeDocument.findFirst({
      where: { id: documentId, businessId },
      select: { id: true, clientId: true },
    });
    if (!document) throw new HttpError(404, 'Document not found');
    await loadClient(prisma, req, document.clientId, { allowArchived: true });
    const rows = await prisma.administrativeDocumentVersion.findMany({
      where: { businessId, documentId },
      orderBy: { versionNumber: 'desc' },
      take: FOLDER_LIST_CAP,
    });
    res.json({ data: rows.map(serializeDocument) });
  }));

  router.post('/:businessId/documents/:documentId/versions', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, documentId } = req.params;
    const b = req.body || {};
    const document = await prisma.administrativeDocument.findFirst({
      where: { id: documentId, businessId },
    });
    if (!document) throw new HttpError(404, 'Document not found');
    const fileName = requireText(b.fileName, 'fileName', 255);
    const fileUrl = requireText(b.fileUrl, 'fileUrl', 2048);
    const fileSizeBytes = b.fileSizeBytes == null
      ? 0
      : intInRange(b.fileSizeBytes, 'fileSizeBytes', 0, Number.MAX_SAFE_INTEGER);
    const mimeType = optionalText(b.mimeType, 'mimeType', 127);
    const action = oneOf(b.action ?? 'store_as_new_version', STORAGE_ACTIONS, 'action');
    const version = await prisma.$transaction(async (tx) => {
      await takeStorage(tx, businessId, BigInt(fileSizeBytes), req.entitlement.storageGb);
      const latest = await tx.administrativeDocumentVersion.findFirst({
        where: { businessId, documentId },
        orderBy: { versionNumber: 'desc' },
        select: { versionNumber: true },
      });
      const created = await tx.administrativeDocumentVersion.create({
        data: {
          businessId, documentId, versionNumber: (latest?.versionNumber ?? 0) + 1,
          fileName, fileUrl, fileSizeBytes: BigInt(fileSizeBytes), mimeType,
          createdBy: me(req),
        },
      });
      if (action === 'replace_original') {
        await tx.administrativeDocument.updateMany({
          where: { id: documentId, businessId },
          data: { fileName, fileUrl, fileSizeBytes: BigInt(fileSizeBytes), mimeType, updatedAt: new Date() },
        });
      }
      await logActivity(tx, {
        businessId, clientId: document.clientId, actorId: me(req),
        action: 'document.version_approved', entityType: 'document', entityId: documentId,
        metadata: { versionId: created.id, action },
      });
      return created;
    });
    res.status(201).json({ data: serializeDocument(version) });
  }));

  router.get('/:businessId/documents/:documentId/download', asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, documentId } = req.params;
    const document = await prisma.administrativeDocument.findFirst({
      where: { id: documentId, businessId },
      select: { id: true, clientId: true, fileName: true, fileUrl: true },
    });
    if (!document) throw new HttpError(404, 'Document not found');
    await loadClient(prisma, req, document.clientId, { allowArchived: true });
    await logActivity(prisma, {
      businessId, clientId: document.clientId, actorId: me(req),
      action: 'document.downloaded', entityType: 'document', entityId: documentId,
      metadata: { fileName: document.fileName },
    });
    res.json({ data: { file_name: document.fileName, file_url: document.fileUrl } });
  }));

  // Assign a stored document to a worker already assigned to its client.
  router.post('/:businessId/documents/:documentId/assignments', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, documentId } = req.params;
    const b = req.body || {};
    const workerId = requireUuid(b.workerId, 'workerId');
    const remark = optionalText(b.remark, 'remark', 1000);
    const dueAt = optionalDateTime(b.dueAt, 'dueAt');

    const doc = await prisma.administrativeDocument.findFirst({
      where: { id: documentId, businessId }, select: { id: true, clientId: true, fileName: true },
    });
    if (!doc) throw new HttpError(404, 'Document not found');
    await requireWorkerInBusiness(prisma, businessId, workerId);
    const link = await prisma.administrativeClientWorker.findUnique({ where: { clientId_workerId: { clientId: doc.clientId, workerId } } });
    if (!link) throw new HttpError(409, 'Assign this worker to the client first');

    const task = await prisma.$transaction(async (tx) => {
      const moved = await tx.administrativeDocument.updateMany({
        where: { id: documentId, businessId, status: 'stored' }, data: { status: 'assigned', updatedAt: new Date() },
      });
      if (moved.count === 0) throw new HttpError(409, 'Document is not available for assignment');
      const t = await tx.administrativeTask.create({
        data: {
          businessId, clientId: doc.clientId, documentId, assignedTo: workerId, assignedBy: me(req),
          title: optionalText(b.title, 'title', 200) || doc.fileName, remark, dueAt, status: 'assigned',
        },
      });
      await logActivity(tx, { businessId, clientId: doc.clientId, actorId: me(req), action: 'document.assigned', entityType: 'document', entityId: documentId, metadata: { workerId, taskId: t.id } });
      return t;
    });
    res.status(201).json({ data: task });
  }));

  // ── Tasks ────────────────────────────────────────────────
  router.get('/:businessId/tasks', pagination, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId } = req.params;
    const where = { businessId };
    if (!isManager(req)) where.assignedTo = me(req);
    else if (req.query.assignedTo !== undefined) where.assignedTo = requireUuid(String(req.query.assignedTo), 'assignedTo');
    if (req.query.status !== undefined) where.status = oneOf(String(req.query.status), TASK_STATUSES, 'status');
    if (req.query.clientId !== undefined) where.clientId = requireUuid(String(req.query.clientId), 'clientId');
    if (req.query.overdue === 'true') {
      where.dueAt = { lt: new Date() };
      if (where.status === undefined) where.status = { in: ['assigned', 'in_progress'] };
    }
    const rows = await prisma.administrativeTask.findMany({
      where, orderBy: [{ dueAt: { sort: 'asc', nulls: 'last' } }, { createdAt: 'desc' }],
      take: req.pagination.limit + 1, skip: req.pagination.offset,
      include: {
        client: { select: { name: true } },
        assignedWorker: { select: { full_name: true } },
      },
    });
    res.json(paged(rows, req.pagination));
  }));

  router.post('/:businessId/tasks', asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId } = req.params;
    const b = req.body || {};
    const manager = isManager(req);
    const data = {
      businessId, assignedBy: me(req), status: 'assigned',
      title: requireText(b.title, 'title'),
      remark: optionalText(b.remark, 'remark', 1000),
      dueAt: optionalDateTime(b.dueAt, 'dueAt'),
      priority: oneOf(b.priority ?? 'normal', ['low', 'normal', 'high', 'urgent'], 'priority'),
    };
    if (manager) {
      data.clientId = optionalUuid(b.clientId, 'clientId');
      data.documentId = optionalUuid(b.documentId, 'documentId');
      data.assignedTo = optionalUuid(b.assignedTo, 'assignedTo');
      if (data.clientId) await loadClient(prisma, req, data.clientId, { allowArchived: true });
      if (data.documentId) {
        const doc = await prisma.administrativeDocument.findFirst({ where: { id: data.documentId, businessId }, select: { clientId: true } });
        if (!doc) throw new HttpError(404, 'Document not found');
        if (data.clientId && data.clientId !== doc.clientId) throw new HttpError(400, 'documentId does not belong to clientId');
        data.clientId = doc.clientId;
      }
      if (data.assignedTo) {
        await requireWorkerInBusiness(prisma, businessId, data.assignedTo);
        if (data.clientId) {
          const assignment = await prisma.administrativeClientWorker.findUnique({
            where: { clientId_workerId: { clientId: data.clientId, workerId: data.assignedTo } },
            select: { clientId: true },
          });
          if (!assignment) throw new HttpError(409, 'Assign this worker to the client first');
        }
      }
    } else {
      data.assignedTo = me(req); // a personal task
    }
    const task = await prisma.$transaction(async (tx) => {
      const t = await tx.administrativeTask.create({ data });
      await logActivity(tx, { businessId, clientId: t.clientId, actorId: me(req), action: 'task.created', entityType: 'task', entityId: t.id });
      return tx.administrativeTask.findFirst({
        where: { id: t.id, businessId },
        include: {
          client: { select: { name: true } },
          assignedWorker: { select: { full_name: true } },
        },
      });
    });
    res.status(201).json({ data: task });
  }));

  async function loadTask(prisma, businessId, taskId) {
    const t = await prisma.administrativeTask.findFirst({ where: { id: taskId, businessId } });
    if (!t) throw new HttpError(404, 'Task not found');
    return t;
  }

  router.get('/:businessId/tasks/:taskId/comments', asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, taskId } = req.params;
    const task = await loadTask(prisma, businessId, taskId);
    if (!isManager(req) && task.assignedTo !== me(req)) {
      throw new HttpError(404, 'Task not found');
    }
    const rows = await prisma.administrativeTaskComment.findMany({
      where: { businessId, taskId },
      orderBy: { createdAt: 'asc' },
    });
    res.json({ data: rows });
  }));

  router.post('/:businessId/tasks/:taskId/comments', asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, taskId } = req.params;
    const task = await loadTask(prisma, businessId, taskId);
    if (!isManager(req) && task.assignedTo !== me(req)) {
      throw new HttpError(404, 'Task not found');
    }
    const body = requireText((req.body || {}).body, 'body', 2000);
    const comment = await prisma.$transaction(async (tx) => {
      const created = await tx.administrativeTaskComment.create({
        data: { businessId, taskId, authorId: me(req), body },
      });
      await logActivity(tx, {
        businessId, clientId: task.clientId, actorId: me(req),
        action: 'task.comment_added', entityType: 'task', entityId: taskId,
      });
      return created;
    });
    res.status(201).json({ data: comment });
  }));

  router.patch('/:businessId/tasks/:taskId', asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, taskId } = req.params;
    const b = req.body || {};
    const task = await loadTask(prisma, businessId, taskId);
    const data = {};
    if (isManager(req)) {
      if (b.title !== undefined) data.title = requireText(b.title, 'title');
      if (b.remark !== undefined) data.remark = optionalText(b.remark, 'remark', 1000);
      if (b.dueAt !== undefined) data.dueAt = optionalDateTime(b.dueAt, 'dueAt');
      if (b.assignedTo !== undefined) {
        data.assignedTo = optionalUuid(b.assignedTo, 'assignedTo');
        if (data.assignedTo) await requireWorkerInBusiness(prisma, businessId, data.assignedTo);
      }
    } else {
      // A worker can only start their own task.
      if (task.assignedTo !== me(req)) throw new HttpError(404, 'Task not found');
      if (b.status !== 'in_progress') throw new HttpError(403, 'You can only mark your own task as in_progress');
      data.status = 'in_progress';
    }
    if (Object.keys(data).length === 0) throw new HttpError(400, 'No valid fields supplied');
    const where = { id: taskId, businessId };
    if (data.status === 'in_progress') where.status = 'assigned'; // only assigned -> in_progress
    const updated = await prisma.$transaction(async (tx) => {
      const r = await tx.administrativeTask.updateMany({ where, data: { ...data, updatedAt: new Date() } });
      if (r.count === 0) throw new HttpError(409, 'Task is not in a state that allows this change');
      if (task.documentId && data.status === 'in_progress') {
        await tx.administrativeDocument.updateMany({ where: { id: task.documentId, businessId, status: 'assigned' }, data: { status: 'in_progress', updatedAt: new Date() } });
      }
      await logActivity(tx, { businessId, clientId: task.clientId, actorId: me(req), action: 'task.updated', entityType: 'task', entityId: taskId, metadata: { fields: Object.keys(data) } });
      return tx.administrativeTask.findFirst({ where: { id: taskId, businessId } });
    });
    res.json({ data: updated });
  }));

  // Worker submits finished work. Only the assignee, only from assigned / in_progress.
  router.post('/:businessId/tasks/:taskId/submit', asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, taskId } = req.params;
    const b = req.body || {};
    const remark = optionalText(b.remark, 'remark', 1000);
    const task = await loadTask(prisma, businessId, taskId);
    if (task.assignedTo !== me(req)) throw new HttpError(403, 'Only the assigned worker can submit this task');
    let submittedVersion = null;
    if (task.documentId) {
      const fileName = requireText(b.fileName, 'fileName', 255);
      const fileUrl = requireText(b.fileUrl, 'fileUrl', 2048);
      const fileSizeBytes = intInRange(b.fileSizeBytes, 'fileSizeBytes', 0, Number.MAX_SAFE_INTEGER);
      const mimeType = optionalText(b.mimeType, 'mimeType', 127);
      submittedVersion = { fileName, fileUrl, fileSizeBytes: BigInt(fileSizeBytes), mimeType };
    }
    const updated = await prisma.$transaction(async (tx) => {
      let submittedVersionId = null;
      if (submittedVersion) {
        const latest = await tx.administrativeDocumentVersion.findFirst({
          where: { businessId, documentId: task.documentId },
          orderBy: { versionNumber: 'desc' },
          select: { versionNumber: true },
        });
        const version = await tx.administrativeDocumentVersion.create({
          data: {
            businessId,
            documentId: task.documentId,
            versionNumber: (latest?.versionNumber ?? 0) + 1,
            ...submittedVersion,
            createdBy: me(req),
          },
        });
        submittedVersionId = version.id;
      }
      const r = await tx.administrativeTask.updateMany({
        where: { id: taskId, businessId, assignedTo: me(req), status: { in: ['assigned', 'in_progress'] } },
        data: { status: 'submitted', submittedVersionId, updatedAt: new Date() },
      });
      if (r.count === 0) throw new HttpError(409, 'Task cannot be submitted from its current status');
      if (task.documentId) {
        await tx.administrativeDocument.updateMany({ where: { id: task.documentId, businessId }, data: { status: 'submitted', updatedAt: new Date() } });
      }
      await logActivity(tx, { businessId, clientId: task.clientId, actorId: me(req), action: 'task.submitted', entityType: 'task', entityId: taskId, metadata: { remark } });
      return tx.administrativeTask.findFirst({
        where: { id: taskId, businessId },
        include: {
          client: { select: { name: true } },
          assignedWorker: { select: { full_name: true } },
        },
      });
    });
    res.json({ data: updated });
  }));

  // Owner / admin approves or rejects submitted work.
  //  approve: needs a storage action (replace_original | store_as_new_version)
  //  reject:  needs a remark, and the task returns to in_progress
  // NOTE: this records the decision. Swapping the stored file / creating the new
  // version needs the administrative_document_versions table the spec lists as
  // future work, so it is not done here.
  router.post('/:businessId/tasks/:taskId/review', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, taskId } = req.params;
    const b = req.body || {};
    const decision = oneOf(b.decision, ['approve', 'reject'], 'decision');
    const remark = optionalText(b.remark, 'remark', 1000);
    let storageAction = null;
    if (decision === 'approve') storageAction = oneOf(b.storageAction, STORAGE_ACTIONS, 'storageAction');
    if (decision === 'reject' && !remark) throw new HttpError(400, 'remark is required when rejecting');

    const task = await loadTask(prisma, businessId, taskId);
    const now = new Date();
    const updated = await prisma.$transaction(async (tx) => {
      const approved = decision === 'approve';
      const version = task.submittedVersionId
        ? await tx.administrativeDocumentVersion.findFirst({
            where: { id: task.submittedVersionId, businessId, documentId: task.documentId },
          })
        : null;
      if (approved && task.documentId && !version) {
        throw new HttpError(409, 'The worker has not submitted a replacement document');
      }
      const r = await tx.administrativeTask.updateMany({
        where: { id: taskId, businessId, status: 'submitted' },
        data: {
          status: approved ? 'approved' : 'in_progress',
          completedAt: approved ? now : null,
          reviewedBy: me(req), reviewedAt: now, reviewAction: approved ? storageAction : 'rejected',
          updatedAt: now,
        },
      });
      if (r.count === 0) throw new HttpError(409, 'Only submitted work can be reviewed');
      if (task.documentId) {
        const documentData = { status: approved ? 'approved' : 'in_progress', updatedAt: now };
        if (approved && storageAction === 'replace_original' && version) {
          Object.assign(documentData, {
            fileName: version.fileName,
            fileUrl: version.fileUrl,
            fileSizeBytes: version.fileSizeBytes,
            mimeType: version.mimeType,
          });
        }
        await tx.administrativeDocument.updateMany({ where: { id: task.documentId, businessId }, data: documentData });
      }
      await logActivity(tx, { businessId, clientId: task.clientId, actorId: me(req), action: approved ? 'task.approved' : 'task.rejected', entityType: 'task', entityId: taskId, metadata: { remark, storageAction } });
      return tx.administrativeTask.findFirst({
        where: { id: taskId, businessId },
        include: {
          client: { select: { name: true } },
          assignedWorker: { select: { full_name: true } },
        },
      });
    });
    res.json({ data: updated });
  }));

  router.get('/:businessId/financial-entries', requireManager, pagination, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId } = req.params;
    const where = { businessId };
    if (req.query.type !== undefined) {
      where.entryType = oneOf(String(req.query.type), ['revenue', 'expense'], 'type');
    }
    if (req.query.clientId !== undefined) {
      where.clientId = requireUuid(String(req.query.clientId), 'clientId');
    }
    const rows = await prisma.administrativeFinancialEntry.findMany({
      where,
      include: { client: { select: { name: true } } },
      orderBy: { occurredAt: 'desc' },
      take: req.pagination.limit + 1,
      skip: req.pagination.offset,
    });
    const result = paged(rows, req.pagination);
    result.data = result.data.map((entry) => ({
      id: entry.id,
      business_id: entry.businessId,
      client_id: entry.clientId,
      client_name: entry.client?.name ?? null,
      invoice_id: entry.invoiceId,
      entry_type: entry.entryType,
      amount: Number(entry.amount),
      occurred_at: entry.occurredAt,
      description: entry.description,
      created_at: entry.createdAt,
    }));
    res.json(result);
  }));

  router.post('/:businessId/financial-entries', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId } = req.params;
    const b = req.body || {};
    const entryType = oneOf(b.entry_type, ['revenue', 'expense'], 'entry_type');
    const amount = Number(b.amount);
    if (!Number.isFinite(amount) || amount < 0) throw new HttpError(400, 'amount must be a non-negative number');
    const clientId = optionalUuid(b.client_id, 'client_id');
    if (clientId) await loadClient(prisma, req, clientId);
    const entry = await prisma.$transaction(async (tx) => {
      const created = await tx.administrativeFinancialEntry.create({
        data: {
          businessId, clientId, entryType, amount,
          description: requireText(b.description, 'description', 1000),
          createdBy: me(req),
        },
      });
      await logActivity(tx, {
        businessId, clientId, actorId: me(req), action: `financial_entry.${entryType}`,
        entityType: 'financial_entry', entityId: created.id,
        metadata: { amount },
      });
      return created;
    });
    res.status(201).json({ data: entry });
  }));

  router.patch('/:businessId/financial-entries/:entryId', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, entryId } = req.params;
    const current = await prisma.administrativeFinancialEntry.findFirst({
      where: { id: entryId, businessId },
    });
    if (!current) throw new HttpError(404, 'Financial entry not found');
    if (current.invoiceId) throw new HttpError(409, 'Invoice payment entries cannot be edited here');
    const b = req.body || {};
    const data = {};
    if (b.entry_type !== undefined) data.entryType = oneOf(b.entry_type, ['revenue', 'expense'], 'entry_type');
    if (b.amount !== undefined) {
      const amount = Number(b.amount);
      if (!Number.isFinite(amount) || amount < 0) throw new HttpError(400, 'amount must be a non-negative number');
      data.amount = amount;
    }
    if (b.description !== undefined) data.description = requireText(b.description, 'description', 1000);
    if (b.client_id !== undefined) {
      data.clientId = optionalUuid(b.client_id, 'client_id');
      if (data.clientId) await loadClient(prisma, req, data.clientId);
    }
    if (Object.keys(data).length === 0) throw new HttpError(400, 'No valid fields supplied');
    const entry = await prisma.$transaction(async (tx) => {
      await tx.administrativeFinancialEntry.updateMany({ where: { id: entryId, businessId }, data });
      await logActivity(tx, {
        businessId, clientId: data.clientId ?? current.clientId, actorId: me(req),
        action: 'financial_entry.updated', entityType: 'financial_entry', entityId: entryId,
        metadata: { fields: Object.keys(data) },
      });
      return tx.administrativeFinancialEntry.findFirst({
        where: { id: entryId, businessId }, include: { client: { select: { name: true } } },
      });
    });
    res.json({ data: {
      id: entry.id, business_id: entry.businessId, client_id: entry.clientId,
      client_name: entry.client?.name ?? null, entry_type: entry.entryType,
      amount: Number(entry.amount), description: entry.description,
      occurred_at: entry.occurredAt,
    } });
  }));

  router.get('/:businessId/invoices', requireManager, pagination, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const rows = await prisma.administrativeInvoice.findMany({
      where: { businessId: req.params.businessId },
      include: { client: { select: { name: true } }, items: true },
      orderBy: { createdAt: 'desc' },
      take: req.pagination.limit + 1,
      skip: req.pagination.offset,
    });
    const result = paged(rows, req.pagination);
    result.data = result.data.map(serializeInvoice);
    res.json(result);
  }));

  router.post('/:businessId/invoices', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId } = req.params;
    const b = req.body || {};
    const clientId = requireUuid(b.client_id, 'client_id');
    await loadClient(prisma, req, clientId);
    if (!Array.isArray(b.items) || b.items.length === 0 || b.items.length > 100) {
      throw new HttpError(400, 'items must contain between 1 and 100 entries');
    }
    const items = b.items.map((item, index) => {
      const quantity = Number(item.quantity);
      const unitPrice = Number(item.unit_price);
      if (!Number.isFinite(quantity) || quantity <= 0) throw new HttpError(400, `items[${index}].quantity must be greater than zero`);
      if (!Number.isFinite(unitPrice) || unitPrice < 0) throw new HttpError(400, `items[${index}].unit_price must be non-negative`);
      return {
        description: requireText(item.description, `items[${index}].description`, 500),
        quantity,
        unitPrice,
        lineTotal: quantity * unitPrice,
      };
    });
    const subtotal = items.reduce((sum, item) => sum + item.lineTotal, 0);
    const taxAmount = Number(b.tax_amount ?? 0);
    if (!Number.isFinite(taxAmount) || taxAmount < 0) throw new HttpError(400, 'tax_amount must be non-negative');
    const totalAmount = subtotal + taxAmount;
    const dueDate = b.due_date == null || b.due_date === '' ? null : parseDateTime(`${b.due_date}T00:00:00.000Z`, 'due_date');
    const invoice = await prisma.$transaction(async (tx) => {
      const created = await tx.administrativeInvoice.create({
        data: {
          businessId, clientId,
          invoiceNumber: requireText(b.invoice_number, 'invoice_number', 80),
          subtotal, taxAmount, totalAmount,
          dueDate, notes: optionalText(b.notes, 'notes', 4000),
          createdBy: me(req),
          items: { create: items },
        },
        include: { client: { select: { name: true } }, items: true },
      });
      await logActivity(tx, {
        businessId, clientId, actorId: me(req), action: 'invoice.created',
        entityType: 'invoice', entityId: created.id,
        metadata: { invoiceNumber: created.invoiceNumber, totalAmount },
      });
      return created;
    });
    res.status(201).json({ data: serializeInvoice(invoice) });
  }));

  router.get('/:businessId/invoices/:invoiceId', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const invoice = await prisma.administrativeInvoice.findFirst({
      where: { id: req.params.invoiceId, businessId: req.params.businessId },
      include: { client: { select: { name: true } }, items: true },
    });
    if (!invoice) throw new HttpError(404, 'Invoice not found');
    res.json(serializeInvoice(invoice));
  }));

  router.post('/:businessId/invoices/:invoiceId/send', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, invoiceId } = req.params;
    const invoice = await prisma.$transaction(async (tx) => {
      const updated = await tx.administrativeInvoice.updateMany({
        where: { id: invoiceId, businessId, status: 'draft' },
        data: { status: 'sent', sentAt: new Date(), updatedAt: new Date() },
      });
      if (updated.count === 0) throw new HttpError(409, 'Only draft invoices can be sent');
      await logActivity(tx, { businessId, actorId: me(req), action: 'invoice.sent', entityType: 'invoice', entityId: invoiceId });
      return tx.administrativeInvoice.findFirst({
        where: { id: invoiceId, businessId },
        include: { client: { select: { name: true } }, items: true },
      });
    });
    res.json({ data: serializeInvoice(invoice) });
  }));

  router.post('/:businessId/invoices/:invoiceId/void', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, invoiceId } = req.params;
    const updated = await prisma.$transaction(async (tx) => {
      const result = await tx.administrativeInvoice.updateMany({
        where: { id: invoiceId, businessId, status: { in: ['draft', 'sent'] } },
        data: { status: 'void', updatedAt: new Date() },
      });
      if (result.count === 0) throw new HttpError(409, 'This invoice can no longer be voided');
      await logActivity(tx, { businessId, actorId: me(req), action: 'invoice.voided', entityType: 'invoice', entityId: invoiceId });
      return tx.administrativeInvoice.findFirst({
        where: { id: invoiceId, businessId },
        include: { client: { select: { name: true } }, items: true },
      });
    });
    res.json({ data: serializeInvoice(updated) });
  }));

  router.post('/:businessId/invoices/:invoiceId/payments', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, invoiceId } = req.params;
    const amount = Number((req.body || {}).amount);
    if (!Number.isFinite(amount) || amount <= 0) throw new HttpError(400, 'amount must be greater than zero');
    const invoice = await prisma.$transaction(async (tx) => {
      const current = await tx.administrativeInvoice.findFirst({ where: { id: invoiceId, businessId } });
      if (!current) throw new HttpError(404, 'Invoice not found');
      if (!['sent', 'paid'].includes(current.status)) throw new HttpError(409, 'Only sent invoices can receive payments');
      const paidAmount = Number(current.paidAmount) + amount;
      if (paidAmount > Number(current.totalAmount) + 0.005) throw new HttpError(400, 'Payment exceeds the remaining invoice balance');
      const fullyPaid = paidAmount >= Number(current.totalAmount) - 0.005;
      const updated = await tx.administrativeInvoice.update({
        where: { id: invoiceId },
        data: {
          paidAmount,
          status: fullyPaid ? 'paid' : 'sent',
          paidAt: fullyPaid ? new Date() : null,
          updatedAt: new Date(),
        },
      });
      await tx.administrativeFinancialEntry.create({
        data: {
          businessId, clientId: current.clientId, invoiceId,
          entryType: 'revenue', amount,
          description: `Payment for invoice ${current.invoiceNumber}`,
          createdBy: me(req),
        },
      });
      await logActivity(tx, {
        businessId, clientId: current.clientId, actorId: me(req),
        action: 'invoice.payment_recorded', entityType: 'invoice', entityId: invoiceId,
        metadata: { amount, paidAmount },
      });
      return tx.administrativeInvoice.findFirst({
        where: { id: updated.id, businessId },
        include: { client: { select: { name: true } }, items: true },
      });
    });
    res.json({ data: serializeInvoice(invoice) });
  }));

  router.post('/:businessId/invoices/:invoiceId/email', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    if (typeof sendMail !== 'function') throw new HttpError(503, 'Invoice email delivery is not configured');
    const { businessId, invoiceId } = req.params;
    const to = requireText((req.body || {}).email, 'email', 254);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(to)) throw new HttpError(400, 'email is invalid');
    const invoice = await prisma.administrativeInvoice.findFirst({
      where: { id: invoiceId, businessId },
      include: { client: { select: { name: true } }, items: true },
    });
    if (!invoice) throw new HttpError(404, 'Invoice not found');
    const escapeHtml = (value) => String(value ?? '').replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char]));
    const lines = invoice.items.map((item) => `<li>${escapeHtml(item.description)} — ${Number(item.quantity)} × ${Number(item.unitPrice).toFixed(2)}</li>`).join('');
    await sendMail({
      to,
      subject: `Invoice ${invoice.invoiceNumber}`,
      html: `<p>Hello ${escapeHtml(invoice.client?.name)},</p><p>Invoice ${escapeHtml(invoice.invoiceNumber)} for NGN ${Number(invoice.totalAmount).toFixed(2)}.</p><ul>${lines}</ul><p>${escapeHtml(invoice.notes)}</p>`,
    });
    if (invoice.status === 'draft') {
      await prisma.administrativeInvoice.updateMany({
        where: { id: invoiceId, businessId, status: 'draft' },
        data: { status: 'sent', sentAt: new Date(), updatedAt: new Date() },
      });
    }
    await logActivity(prisma, { businessId, clientId: invoice.clientId, actorId: me(req), action: 'invoice.emailed', entityType: 'invoice', entityId: invoiceId, metadata: { to } });
    res.json({ data: { id: invoiceId, sent: true } });
  }));

  // ── Obligations ──────────────────────────────────────────
  router.get('/:businessId/obligations', pagination, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId } = req.params;
    const where = { businessId, isActive: req.query.active === 'false' ? false : true };
    if (!isManager(req)) where.assignedTo = me(req);
    if (req.query.clientId !== undefined) where.clientId = requireUuid(String(req.query.clientId), 'clientId');
    if (req.query.due !== undefined) {
      const due = oneOf(String(req.query.due), ['overdue', '24h', '3d', '7d'], 'due');
      const now = Date.now();
      where.nextDueAt = due === 'overdue' ? { lt: new Date(now) }
        : { lt: new Date(now + { '24h': 1, '3d': 3, '7d': 7 }[due] * DAY_MS) };
    }
    const rows = await prisma.administrativeObligation.findMany({
      where,
      include: { client: { select: { name: true } } },
      orderBy: { nextDueAt: 'asc' },
      take: req.pagination.limit + 1,
      skip: req.pagination.offset,
    });
    res.json(paged(rows, req.pagination));
  }));

  router.post('/:businessId/obligations', requireManager, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId } = req.params;
    const b = req.body || {};
    const clientId = requireUuid(b.clientId, 'clientId');
    const recurrenceType = oneOf(b.recurrenceType, ['fixed', 'trailing'], 'recurrenceType');
    const intervalDays = intInRange(b.intervalDays, 'intervalDays', 1, 3650);
    let fixedDayOfMonth = null;
    if (b.fixedDayOfMonth !== undefined && b.fixedDayOfMonth !== null) {
      if (recurrenceType !== 'fixed') throw new HttpError(400, 'fixedDayOfMonth only applies to fixed recurrence');
      fixedDayOfMonth = intInRange(b.fixedDayOfMonth, 'fixedDayOfMonth', 1, 31);
      if (intervalDays < 28) throw new HttpError(400, 'fixedDayOfMonth needs an intervalDays of at least 28');
    }
    const data = {
      businessId, clientId, recurrenceType, intervalDays, fixedDayOfMonth,
      title: requireText(b.title, 'title'),
      nextDueAt: parseDateTime(b.nextDueAt, 'nextDueAt'),
      assignedTo: optionalUuid(b.assignedTo, 'assignedTo'),
      createdBy: me(req),
    };
    await loadClient(prisma, req, clientId);
    if (data.assignedTo) await requireWorkerInBusiness(prisma, businessId, data.assignedTo);
    const created = await prisma.$transaction(async (tx) => {
      const o = await tx.administrativeObligation.create({
        data,
        include: { client: { select: { name: true } } },
      });
      await logActivity(tx, { businessId, clientId, actorId: me(req), action: 'obligation.created', entityType: 'obligation', entityId: o.id });
      return o;
    });
    res.status(201).json({ data: created });
  }));

  // Complete the current occurrence and move to the next. The previous due date
  // is kept in the activity log, so history is not lost.
  //
  // Double-submit protection has two layers:
  //  1. expectedDueAt (optional body field): the due date the client was showing.
  //     If it no longer matches, the occurrence was already completed -> 409.
  //     This is the layer that catches a double click that arrives AFTER the
  //     first request committed. Clients should always send it.
  //  2. The update below only matches the due date this request read, so two
  //     requests that read the same state cannot both advance it.
  // Without expectedDueAt, a second request that arrives after the first has
  // committed is indistinguishable from a genuine completion of the next
  // occurrence, and is accepted.
  router.post('/:businessId/obligations/:obligationId/complete', asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const { businessId, obligationId } = req.params;
    let expectedDueAt = null;
    if (req.body && req.body.expectedDueAt !== undefined && req.body.expectedDueAt !== null) {
      expectedDueAt = new Date(req.body.expectedDueAt);
      if (Number.isNaN(expectedDueAt.getTime())) throw new HttpError(400, 'expectedDueAt must be a valid date');
    }
    const ob = await prisma.administrativeObligation.findFirst({ where: { id: obligationId, businessId, isActive: true } });
    if (!ob) throw new HttpError(404, 'Obligation not found');
    if (!isManager(req) && ob.assignedTo !== me(req)) throw new HttpError(404, 'Obligation not found');
    if (expectedDueAt && expectedDueAt.getTime() !== ob.nextDueAt.getTime()) {
      throw new HttpError(409, 'This obligation was just updated. Reload and try again.');
    }

    const completedAt = new Date();
    const nextDueAt = computeNextDue(ob, completedAt);
    const updated = await prisma.$transaction(async (tx) => {
      const r = await tx.administrativeObligation.updateMany({
        where: { id: obligationId, businessId, isActive: true, nextDueAt: ob.nextDueAt },
        data: { nextDueAt, lastCompletedAt: completedAt, updatedAt: completedAt },
      });
      if (r.count === 0) throw new HttpError(409, 'This obligation was just updated. Reload and try again.');
      await logActivity(tx, {
        businessId, clientId: ob.clientId, actorId: me(req), action: 'obligation.completed',
        entityType: 'obligation', entityId: obligationId,
        metadata: { previousDueAt: ob.nextDueAt, completedAt, nextDueAt },
      });
      return tx.administrativeObligation.findFirst({ where: { id: obligationId, businessId } });
    });
    res.json({ data: updated });
  }));

  // ── Activity (owner / admin) ─────────────────────────────
  router.get('/:businessId/activity', requireManager, pagination, asyncHandler(async (req, res) => {
    const prisma = await getPrisma();
    const where = { businessId: req.params.businessId };
    if (req.query.clientId !== undefined) where.clientId = requireUuid(String(req.query.clientId), 'clientId');
    if (typeof req.query.entityType === 'string') where.entityType = req.query.entityType.slice(0, 50);
    if (typeof req.query.action === 'string') where.action = req.query.action.slice(0, 80);
    const rows = await prisma.administrativeActivityLog.findMany({
      where, orderBy: { createdAt: 'desc' }, take: req.pagination.limit + 1, skip: req.pagination.offset,
    });
    res.json(paged(rows, req.pagination));
  }));

  // ── Errors: shape this router's own errors, pass the rest on ──
  // eslint-disable-next-line no-unused-vars
  router.use((err, _req, res, next) => {
    if (err instanceof HttpError) {
      return res.status(err.statusCode).json({ error: err.message, ...(err.extra || {}) });
    }
    // Prisma known-request errors (the global handler only knows raw pg codes).
    if (err && err.code === 'P2002') return res.status(409).json({ error: 'A record with this value already exists' });
    if (err && err.code === 'P2003') return res.status(400).json({ error: 'Referenced record does not exist' });
    if (err && err.code === 'P2025') return res.status(404).json({ error: 'Record not found' });
    next(err);
  });

  return router;
};

module.exports.invalidateEntitlement = invalidateEntitlement;
module.exports.computeNextDue = computeNextDue;
module.exports.TIER_LIMITS = TIER_LIMITS;
