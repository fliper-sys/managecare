const express = require('express');
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const { asyncHandler, requireFields } = require('../middleware/validation');
const { requireBusinessMembership } = require('../middleware/auth');

module.exports = function administrativeRoutes(pool, { sendMail } = {}) {
  const router = express.Router();
  router.use('/:businessId', requireBusinessMembership(pool));

  const planLimits = {
    tier1: { clients: 30, workers: 4, storageBytes: 4 * 1024 * 1024 * 1024 },
    tier2: { clients: 75, workers: 10, storageBytes: 10 * 1024 * 1024 * 1024 },
    tier3: { clients: 200, workers: 20, storageBytes: 25 * 1024 * 1024 * 1024 },
    premium: { clients: 400, workers: 50, storageBytes: 50 * 1024 * 1024 * 1024 },
    enterprise: { clients: null, workers: null, storageBytes: null },
  };

  router.use('/:businessId', asyncHandler(async (req, res, next) => {
    const result = await pool.query(
      `SELECT business_type, subscription_tier, is_subscription_active,
              subscription_end_date
       FROM businesses WHERE id = $1`,
      [req.params.businessId],
    );
    const business = result.rows[0];
    if (!business || String(business.business_type || '').toLowerCase() !== 'administrative') {
      return res.status(403).json({ error: 'Administrative workspace is not enabled for this business' });
    }
    const expired = business.subscription_end_date && new Date(business.subscription_end_date) < new Date();
    if (!business.is_subscription_active || expired) {
      return res.status(402).json({ error: 'An active administrative subscription is required' });
    }
    req.administrativeLimits = planLimits[String(business.subscription_tier || '').toLowerCase()] || planLimits.tier1;
    next();
  }));

  const isManager = (req) => {
    const membership = req.businessMembership;
    return membership?.is_owner || ['owner', 'admin', 'sub_admin'].includes(
      String(membership?.role || '').toLowerCase(),
    );
  };

  const requireManager = (req, res, next) => {
    if (!isManager(req)) return res.status(403).json({ error: 'Administrative access is required' });
    next();
  };

  const enforceLimit = async (req, res, type, incoming = 0) => {
    const config = req.administrativeLimits;
    const limit = type === 'clients' ? config.clients : config.storageBytes;
    if (limit == null) return true;
    const { businessId } = req.params;
    const result = type === 'clients'
      ? await pool.query('SELECT COUNT(*)::int AS usage FROM administrative_clients WHERE business_id = $1 AND is_active = true', [businessId])
      : await pool.query('SELECT COALESCE(SUM(file_size_bytes), 0)::bigint AS usage FROM administrative_documents WHERE business_id = $1', [businessId]);
    const usage = Number(result.rows[0].usage || 0);
    if (usage + Math.max(0, Number(incoming) || 0) > limit) {
      res.status(409).json({ error: 'Subscription limit reached', limit_type: type, limit, current_usage: usage });
      return false;
    }
    return true;
  };

  const logActivity = async (businessId, actorId, action, entityType, entityId, clientId, metadata = {}) => {
    await pool.query(
      `INSERT INTO administrative_activity_log
       (business_id, client_id, actor_id, action, entity_type, entity_id, metadata)
       VALUES ($1, $2, $3, $4, $5, $6::uuid, $7::jsonb)`,
      [businessId, clientId || null, actorId, action, entityType, entityId, JSON.stringify(metadata)],
    );
  };

  const credentialKey = () => {
    const value = process.env.ADMIN_CREDENTIAL_ENCRYPTION_KEY || '';
    const key = /^[0-9a-f]{64}$/i.test(value) ? Buffer.from(value, 'hex') : Buffer.from(value, 'base64');
    return key.length === 32 ? key : null;
  };
  const encryptCredentials = (credentials) => {
    const key = credentialKey();
    if (!key) throw new Error('ADMIN_CREDENTIAL_ENCRYPTION_KEY must be a 32-byte base64 or 64-character hex value');
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
    const ciphertext = Buffer.concat([cipher.update(JSON.stringify(credentials), 'utf8'), cipher.final()]);
    return { alg: 'aes-256-gcm', iv: iv.toString('base64'), tag: cipher.getAuthTag().toString('base64'), ciphertext: ciphertext.toString('base64') };
  };
  const decryptCredentials = (value) => {
    const key = credentialKey();
    if (!key || !value?.ciphertext || !value?.iv || !value?.tag) throw new Error('Credentials cannot be decrypted');
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, Buffer.from(value.iv, 'base64'));
    decipher.setAuthTag(Buffer.from(value.tag, 'base64'));
    return JSON.parse(Buffer.concat([decipher.update(Buffer.from(value.ciphertext, 'base64')), decipher.final()]).toString('utf8'));
  };

  const nextFixedDate = (date, requestedDay) => {
    const day = Math.max(1, Math.min(31, Number(requestedDay) || date.getUTCDate()));
    const lastDay = (year, month) => new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
    let year = date.getUTCFullYear();
    let month = date.getUTCMonth();
    let due = new Date(Date.UTC(year, month, Math.min(day, lastDay(year, month))));
    if (due <= date) {
      month += 1;
      if (month === 12) {
        month = 0;
        year += 1;
      }
      due = new Date(Date.UTC(year, month, Math.min(day, lastDay(year, month))));
    }
    return due;
  };

  const requireClientAccess = async (req, res, businessId, clientId) => {
    const params = [clientId, businessId];
    let query = `SELECT c.* FROM administrative_clients c
                 WHERE c.id = $1 AND c.business_id = $2`;
    if (!isManager(req)) {
      params.push(req.user.id);
      query += ` AND EXISTS (
        SELECT 1 FROM administrative_client_workers cw
        WHERE cw.client_id = c.id AND cw.worker_id = $3
      )`;
    }
    const result = await pool.query(query, params);
    if (result.rows.length === 0) {
      res.status(404).json({ error: 'Client not found or not accessible' });
      return null;
    }
    return result.rows[0];
  };

  router.get('/:businessId/dashboard', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const accessible = isManager(req)
      ? ''
      : ` AND EXISTS (SELECT 1 FROM administrative_client_workers cw
                       WHERE cw.client_id = c.id AND cw.worker_id = $2)`;
    const assignedTask = isManager(req) ? '' : ' AND t.assigned_to = $2';
    const assignedObligation = isManager(req) ? '' : ' AND o.assigned_to = $2';
    const params = isManager(req) ? [businessId] : [businessId, req.user.id];
    const result = await pool.query(
      `SELECT
         (SELECT COUNT(*)::int FROM administrative_clients c
          WHERE c.business_id = $1 AND c.is_active = true${accessible}) AS client_count,
         (SELECT COUNT(*)::int FROM administrative_tasks t
          WHERE t.business_id = $1 AND t.status = 'submitted'${assignedTask}) AS review_count,
         (SELECT COUNT(*)::int FROM administrative_obligations o
          WHERE o.business_id = $1 AND o.is_active = true
            AND o.next_due_at <= NOW() + INTERVAL '7 days'${assignedObligation}) AS urgent_obligation_count`,
      params,
    );
    res.json(result.rows[0]);
  }));

  router.get('/:businessId/clients', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { q, location, active = 'true', limit = '50', offset = '0' } = req.query;
    const params = [businessId];
    let query = `SELECT c.*, 
      (SELECT COUNT(*)::int FROM administrative_client_workers cw WHERE cw.client_id = c.id) AS worker_count,
      (SELECT COUNT(*)::int FROM administrative_documents d WHERE d.client_id = c.id) AS document_count,
      (SELECT COUNT(*)::int FROM administrative_tasks t WHERE t.client_id = c.id AND t.status IN ('assigned', 'in_progress', 'submitted')) AS open_task_count,
      (SELECT MIN(o.next_due_at) FROM administrative_obligations o WHERE o.client_id = c.id AND o.is_active = true) AS next_obligation_at
      FROM administrative_clients c WHERE c.business_id = $1`;
    if (!isManager(req)) {
      params.push(req.user.id);
      query += ` AND EXISTS (SELECT 1 FROM administrative_client_workers cw WHERE cw.client_id = c.id AND cw.worker_id = $${params.length})`;
    }
    if (active === 'true' || active === 'false') { params.push(active === 'true'); query += ` AND c.is_active = $${params.length}`; }
    if (location) { params.push(location); query += ` AND c.location = $${params.length}`; }
    if (q) {
      params.push(`%${q}%`);
      query += ` AND (c.name ILIKE $${params.length} OR c.company_name ILIKE $${params.length} OR c.location ILIKE $${params.length})`;
    }
    params.push(Math.min(100, Math.max(1, Number(limit) || 50)));
    params.push(Math.max(0, Number(offset) || 0));
    query += ` ORDER BY c.name ASC LIMIT $${params.length - 1} OFFSET $${params.length}`;
    const result = await pool.query(query, params);
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/clients', requireManager, requireFields('name'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { name, company_name, location, contact_address } = req.body;
    if (!await enforceLimit(req, res, 'clients', 1)) return;
    const result = await pool.query(
      `INSERT INTO administrative_clients (business_id, name, company_name, location, contact_address, created_by)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [businessId, name.trim(), company_name || null, location || null, contact_address || null, req.user.id],
    );
    const client = result.rows[0];
    await logActivity(businessId, req.user.id, 'client_created', 'client', client.id, client.id);
    res.status(201).json(client);
  }));

  router.get('/:businessId/clients/:clientId', asyncHandler(async (req, res) => {
    const { businessId, clientId } = req.params;
    const client = await requireClientAccess(req, res, businessId, clientId);
    if (!client) return;
    const response = { ...client };
    delete response.portal_credentials;
    await logActivity(businessId, req.user.id, 'client_viewed', 'client', clientId, clientId);
    res.json(response);
  }));

  router.patch('/:businessId/clients/:clientId', requireManager, asyncHandler(async (req, res) => {
    const { businessId, clientId } = req.params;
    const allowed = ['name', 'company_name', 'location', 'contact_address', 'portal_credentials', 'is_active'];
    const fields = [];
    const values = [];
    for (const key of allowed) {
      if (req.body[key] !== undefined) {
        values.push(key === 'portal_credentials' ? JSON.stringify(encryptCredentials(req.body[key])) : req.body[key]);
        fields.push(`${key} = $${values.length}${key === 'portal_credentials' ? '::jsonb' : ''}`);
      }
    }
    if (fields.length === 0) return res.status(400).json({ error: 'No supported client fields supplied' });
    if (req.body.is_active === false) fields.push('archived_at = NOW()');
    if (req.body.is_active === true) fields.push('archived_at = NULL');
    values.push(clientId, businessId);
    const result = await pool.query(
      `UPDATE administrative_clients SET ${fields.join(', ')}, updated_at = NOW()
       WHERE id = $${values.length - 1} AND business_id = $${values.length} RETURNING *`,
      values,
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Client not found' });
    await logActivity(businessId, req.user.id, req.body.is_active === false ? 'client_archived' : 'client_updated', 'client', clientId, clientId);
    res.json(result.rows[0]);
  }));

  router.put('/:businessId/clients/:clientId/access-passcode', requireManager, requireFields('passcode'), asyncHandler(async (req, res) => {
    const { businessId, clientId } = req.params;
    const passcode = String(req.body.passcode || '');
    if (passcode.length < 6) return res.status(400).json({ error: 'Passcode must contain at least 6 characters' });
    const hash = await bcrypt.hash(passcode, 12);
    const result = await pool.query('UPDATE administrative_clients SET revenue_access_pin_hash = $1, updated_at = NOW() WHERE id = $2 AND business_id = $3 RETURNING id', [hash, clientId, businessId]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Client not found' });
    await logActivity(businessId, req.user.id, 'client_access_passcode_set', 'client', clientId, clientId);
    res.status(204).end();
  }));

  router.post('/:businessId/clients/:clientId/credentials/reveal', requireManager, requireFields('passcode'), asyncHandler(async (req, res) => {
    const { businessId, clientId } = req.params;
    const result = await pool.query('SELECT portal_credentials, revenue_access_pin_hash FROM administrative_clients WHERE id = $1 AND business_id = $2', [clientId, businessId]);
    const client = result.rows[0];
    if (!client) return res.status(404).json({ error: 'Client not found' });
    if (!client.revenue_access_pin_hash || !await bcrypt.compare(String(req.body.passcode), client.revenue_access_pin_hash)) return res.status(403).json({ error: 'Invalid client access passcode' });
    let credentials;
    try { credentials = decryptCredentials(client.portal_credentials); } catch (_) { return res.status(409).json({ error: 'Credentials are not available or were stored with an unavailable encryption key' }); }
    await logActivity(businessId, req.user.id, 'client_credentials_revealed', 'client', clientId, clientId);
    res.json({ credentials });
  }));

  router.post('/:businessId/clients/:clientId/credentials/copy-audit', requireManager, asyncHandler(async (req, res) => {
    const { businessId, clientId } = req.params;
    await logActivity(businessId, req.user.id, 'client_credentials_copied', 'client', clientId, clientId, { field: req.body.field || 'unknown' });
    res.status(204).end();
  }));

  router.put('/:businessId/clients/:clientId/workers/:workerId', requireManager, asyncHandler(async (req, res) => {
    const { businessId, clientId, workerId } = req.params;
    const client = await requireClientAccess(req, res, businessId, clientId);
    if (!client) return;
    const worker = await pool.query('SELECT id FROM workers WHERE id = $1 AND business_id = $2 AND is_active = true', [workerId, businessId]);
    if (worker.rows.length === 0) return res.status(400).json({ error: 'Active worker not found for this business' });
    await pool.query(
      `INSERT INTO administrative_client_workers (client_id, worker_id, assigned_by)
       VALUES ($1, $2, $3) ON CONFLICT (client_id, worker_id) DO NOTHING`,
      [clientId, workerId, req.user.id],
    );
    await logActivity(businessId, req.user.id, 'client_worker_assigned', 'client', clientId, clientId, { worker_id: workerId });
    res.status(204).end();
  }));

  router.delete('/:businessId/clients/:clientId/workers/:workerId', requireManager, asyncHandler(async (req, res) => {
    const { businessId, clientId, workerId } = req.params;
    const client = await requireClientAccess(req, res, businessId, clientId);
    if (!client) return;
    await pool.query('DELETE FROM administrative_client_workers WHERE client_id = $1 AND worker_id = $2', [clientId, workerId]);
    await logActivity(businessId, req.user.id, 'client_worker_unassigned', 'client', clientId, clientId, { worker_id: workerId });
    res.status(204).end();
  }));

  router.get('/:businessId/clients/:clientId/folders', asyncHandler(async (req, res) => {
    const { businessId, clientId } = req.params;
    const client = await requireClientAccess(req, res, businessId, clientId);
    if (!client) return;
    const result = await pool.query(
      `SELECT f.*, COUNT(d.id)::int AS document_count
       FROM administrative_document_folders f
       LEFT JOIN administrative_documents d ON d.folder_id = f.id
       WHERE f.business_id = $1 AND f.client_id = $2
       GROUP BY f.id ORDER BY f.name ASC`,
      [businessId, clientId],
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/clients/:clientId/folders', requireManager, requireFields('name'), asyncHandler(async (req, res) => {
    const { businessId, clientId } = req.params;
    const client = await requireClientAccess(req, res, businessId, clientId);
    if (!client) return;
    const result = await pool.query(
      `INSERT INTO administrative_document_folders (business_id, client_id, name, created_by)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [businessId, clientId, req.body.name.trim(), req.user.id],
    );
    const folder = result.rows[0];
    await logActivity(businessId, req.user.id, 'document_folder_created', 'folder', folder.id, clientId, { name: folder.name });
    res.status(201).json(folder);
  }));

  router.get('/:businessId/clients/:clientId/documents', asyncHandler(async (req, res) => {
    const { businessId, clientId } = req.params;
    const client = await requireClientAccess(req, res, businessId, clientId);
    if (!client) return;
    const { folderId, q, mimeType, status, limit = '50', offset = '0' } = req.query;
    const params = [businessId, clientId];
    let query = `SELECT d.*, f.name AS folder_name, p.full_name AS uploaded_by_name
                 FROM administrative_documents d
                 LEFT JOIN administrative_document_folders f ON f.id = d.folder_id
                 LEFT JOIN profiles p ON p.id = d.uploaded_by
                 WHERE d.business_id = $1 AND d.client_id = $2`;
    if (folderId) { params.push(folderId); query += ` AND d.folder_id = $${params.length}`; }
    if (status) { params.push(status); query += ` AND d.status = $${params.length}`; }
    if (mimeType) { params.push(mimeType); query += ` AND d.mime_type = $${params.length}`; }
    if (q) { params.push(`%${q}%`); query += ` AND d.file_name ILIKE $${params.length}`; }
    params.push(Math.min(100, Math.max(1, Number(limit) || 50)));
    params.push(Math.max(0, Number(offset) || 0));
    query += ` ORDER BY d.created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`;
    const result = await pool.query(query, params);
    await logActivity(businessId, req.user.id, 'documents_listed', 'client', clientId, clientId);
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/clients/:clientId/documents', requireManager, requireFields('file_name', 'file_url'), asyncHandler(async (req, res) => {
    const { businessId, clientId } = req.params;
    const client = await requireClientAccess(req, res, businessId, clientId);
    if (!client) return;
    const { file_name, file_url, folder_id, file_size_bytes, mime_type } = req.body;
    if (!await enforceLimit(req, res, 'storage', file_size_bytes)) return;
    if (folder_id) {
      const folder = await pool.query(
        'SELECT id FROM administrative_document_folders WHERE id = $1 AND client_id = $2 AND business_id = $3',
        [folder_id, clientId, businessId],
      );
      if (folder.rows.length === 0) return res.status(400).json({ error: 'Folder does not belong to this client' });
    }
    const result = await pool.query(
      `INSERT INTO administrative_documents
       (business_id, client_id, folder_id, file_name, file_url, file_size_bytes, mime_type, uploaded_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
      [businessId, clientId, folder_id || null, file_name.trim(), file_url, file_size_bytes || null, mime_type || null, req.user.id],
    );
    const document = result.rows[0];
    await pool.query(
      `INSERT INTO administrative_document_versions
       (business_id, document_id, version_number, file_name, file_url, file_size_bytes, mime_type, created_by)
       VALUES ($1, $2, 1, $3, $4, $5, $6, $7)`,
      [businessId, document.id, document.file_name, document.file_url, document.file_size_bytes, document.mime_type, req.user.id],
    );
    await logActivity(businessId, req.user.id, 'document_uploaded', 'document', document.id, clientId, { file_name: document.file_name });
    res.status(201).json(document);
  }));

  router.get('/:businessId/documents/:documentId/versions', asyncHandler(async (req, res) => {
    const { businessId, documentId } = req.params;
    const result = await pool.query('SELECT * FROM administrative_documents WHERE id = $1 AND business_id = $2', [documentId, businessId]);
    const document = result.rows[0];
    if (!document) return res.status(404).json({ error: 'Document not found' });
    const client = await requireClientAccess(req, res, businessId, document.client_id);
    if (!client) return;
    const versions = await pool.query(
      'SELECT * FROM administrative_document_versions WHERE document_id = $1 ORDER BY version_number DESC',
      [documentId],
    );
    res.json({ data: versions.rows });
  }));

  router.post('/:businessId/documents/:documentId/versions', requireManager, requireFields('file_name', 'file_url', 'action'), asyncHandler(async (req, res) => {
    const { businessId, documentId } = req.params;
    const { file_name, file_url, file_size_bytes, mime_type, action } = req.body;
    if (!['replace', 'new_version'].includes(action)) return res.status(400).json({ error: 'action must be replace or new_version' });
    const found = await pool.query('SELECT * FROM administrative_documents WHERE id = $1 AND business_id = $2', [documentId, businessId]);
    const document = found.rows[0];
    if (!document) return res.status(404).json({ error: 'Document not found' });
    if (!await requireClientAccess(req, res, businessId, document.client_id)) return;
    if (!await enforceLimit(req, res, 'storage', file_size_bytes)) return;
    const versionResult = await pool.query('SELECT COALESCE(MAX(version_number), 0)::int AS version FROM administrative_document_versions WHERE document_id = $1', [documentId]);
    const version = Number(versionResult.rows[0].version) + 1;
    await pool.query(
      `INSERT INTO administrative_document_versions
       (business_id, document_id, version_number, file_name, file_url, file_size_bytes, mime_type, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [businessId, documentId, version, file_name.trim(), file_url, file_size_bytes || null, mime_type || null, req.user.id],
    );
    if (action === 'replace') {
      await pool.query(
        `UPDATE administrative_documents SET file_name = $1, file_url = $2, file_size_bytes = $3, mime_type = $4, updated_at = NOW()
         WHERE id = $5`,
        [file_name.trim(), file_url, file_size_bytes || null, mime_type || null, documentId],
      );
    }
    await logActivity(businessId, req.user.id, 'document_version_approved', 'document', documentId, document.client_id, { action, version });
    res.status(201).json({ document_id: documentId, version_number: version, action });
  }));

  router.get('/:businessId/documents/:documentId/download', asyncHandler(async (req, res) => {
    const { businessId, documentId } = req.params;
    const result = await pool.query(
      `SELECT d.* FROM administrative_documents d
       WHERE d.id = $1 AND d.business_id = $2`,
      [documentId, businessId],
    );
    const document = result.rows[0];
    if (!document) return res.status(404).json({ error: 'Document not found' });
    const client = await requireClientAccess(req, res, businessId, document.client_id);
    if (!client) return;
    await logActivity(businessId, req.user.id, 'document_downloaded', 'document', documentId, document.client_id, { file_name: document.file_name });
    res.json({ file_name: document.file_name, file_url: document.file_url, mime_type: document.mime_type });
  }));

  router.get('/:businessId/activity', requireManager, asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { clientId, action, limit = '100', offset = '0' } = req.query;
    const params = [businessId];
    let query = `SELECT a.*, c.name AS client_name, p.full_name AS actor_name
                 FROM administrative_activity_log a
                 LEFT JOIN administrative_clients c ON c.id = a.client_id
                 LEFT JOIN profiles p ON p.id = a.actor_id
                 WHERE a.business_id = $1`;
    if (clientId) { params.push(clientId); query += ` AND a.client_id = $${params.length}`; }
    if (action) { params.push(action); query += ` AND a.action = $${params.length}`; }
    params.push(Math.min(200, Math.max(1, Number(limit) || 100)));
    params.push(Math.max(0, Number(offset) || 0));
    query += ` ORDER BY a.created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`;
    const result = await pool.query(query, params);
    res.json({ data: result.rows });
  }));

  router.get('/:businessId/staffing', requireManager, asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const result = await pool.query(
      `SELECT w.id, w.full_name, w.role, w.is_active,
              COUNT(DISTINCT cw.client_id)::int AS assigned_client_count,
              COALESCE(array_agg(DISTINCT cw.client_id) FILTER (WHERE cw.client_id IS NOT NULL), '{}') AS assigned_client_ids,
              COUNT(DISTINCT t.id) FILTER (WHERE t.status IN ('assigned', 'in_progress', 'submitted'))::int AS open_task_count
       FROM workers w
       LEFT JOIN administrative_client_workers cw ON cw.worker_id = w.id
       LEFT JOIN administrative_tasks t ON t.assigned_to = w.id AND t.business_id = $1
       WHERE w.business_id = $1
       GROUP BY w.id ORDER BY w.full_name ASC`,
      [businessId],
    );
    res.json({ data: result.rows });
  }));

  router.get('/:businessId/calendar', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { from, to } = req.query;
    if (!from || !to) return res.status(400).json({ error: 'from and to are required' });
    const params = [businessId, from, to];
    const taskScope = isManager(req) ? '' : ' AND t.assigned_to = $4';
    const obligationScope = isManager(req) ? '' : ' AND o.assigned_to = $4';
    if (!isManager(req)) params.push(req.user.id);
    const result = await pool.query(
      `SELECT 'task' AS event_type, t.id, t.title, t.due_at AS starts_at, t.status,
              t.client_id, c.name AS client_name
       FROM administrative_tasks t
       LEFT JOIN administrative_clients c ON c.id = t.client_id
       WHERE t.business_id = $1 AND t.due_at >= $2::timestamptz
         AND t.due_at < $3::timestamptz${taskScope}
       UNION ALL
       SELECT 'obligation' AS event_type, o.id, o.title, o.next_due_at AS starts_at,
              CASE WHEN o.next_due_at <= NOW() + INTERVAL '7 days' THEN 'urgent' ELSE 'open' END AS status,
              o.client_id, c.name AS client_name
       FROM administrative_obligations o
       JOIN administrative_clients c ON c.id = o.client_id
       WHERE o.business_id = $1 AND o.is_active = true
         AND o.next_due_at >= $2::timestamptz
         AND o.next_due_at < $3::timestamptz${obligationScope}
       UNION ALL
       SELECT 'calendar' AS event_type, e.id, e.title, e.starts_at,
              'scheduled' AS status, e.client_id, c.name AS client_name
       FROM administrative_calendar_events e
       LEFT JOIN administrative_clients c ON c.id = e.client_id
       WHERE e.business_id = $1 AND e.starts_at >= $2::timestamptz
         AND e.starts_at < $3::timestamptz
       ORDER BY starts_at ASC`,
      params,
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/calendar-events', requireManager, requireFields('title', 'starts_at'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { title, description, starts_at, client_id } = req.body;
    if (Number.isNaN(Date.parse(starts_at))) return res.status(400).json({ error: 'starts_at must be a valid date' });
    if (client_id && !await requireClientAccess(req, res, businessId, client_id)) return;
    const result = await pool.query(
      `INSERT INTO administrative_calendar_events (business_id, client_id, title, description, starts_at, created_by)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [businessId, client_id || null, title.trim(), description?.trim() || null, starts_at, req.user.id],
    );
    const event = result.rows[0];
    await logActivity(businessId, req.user.id, 'calendar_event_created', 'calendar_event', event.id, event.client_id);
    res.status(201).json(event);
  }));

  router.get('/:businessId/financial-entries', requireManager, asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { type, clientId, from, to, limit = '100', offset = '0' } = req.query;
    const params = [businessId];
    let query = `SELECT e.*, c.name AS client_name
                 FROM administrative_financial_entries e
                 LEFT JOIN administrative_clients c ON c.id = e.client_id
                 WHERE e.business_id = $1`;
    if (type) { if (!['revenue', 'expense'].includes(type)) return res.status(400).json({ error: 'Invalid entry type' }); params.push(type); query += ` AND e.entry_type = $${params.length}`; }
    if (clientId) { params.push(clientId); query += ` AND e.client_id = $${params.length}`; }
    if (from) { params.push(from); query += ` AND e.occurred_at >= $${params.length}::timestamptz`; }
    if (to) { params.push(to); query += ` AND e.occurred_at < $${params.length}::timestamptz`; }
    params.push(Math.min(200, Math.max(1, Number(limit) || 100)), Math.max(0, Number(offset) || 0));
    query += ` ORDER BY e.occurred_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`;
    const result = await pool.query(query, params);
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/financial-entries', requireManager, requireFields('entry_type', 'amount', 'description'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { entry_type, amount, description, client_id, occurred_at } = req.body;
    if (!['revenue', 'expense'].includes(entry_type) || Number(amount) < 0) return res.status(400).json({ error: 'Invalid financial entry' });
    const result = await pool.query(
      `INSERT INTO administrative_financial_entries
       (business_id, client_id, entry_type, amount, occurred_at, description, created_by)
       VALUES ($1, $2, $3, $4, COALESCE($5::timestamptz, NOW()), $6, $7) RETURNING *`,
      [businessId, client_id || null, entry_type, amount, occurred_at || null, description.trim(), req.user.id],
    );
    const entry = result.rows[0];
    await logActivity(businessId, req.user.id, `${entry_type}_recorded`, 'financial_entry', entry.id, entry.client_id);
    res.status(201).json(entry);
  }));

  router.patch('/:businessId/financial-entries/:entryId', requireManager, asyncHandler(async (req, res) => {
    const { businessId, entryId } = req.params;
    const { entry_type, amount, description, client_id, occurred_at } = req.body;
    if (entry_type !== undefined && !['revenue', 'expense'].includes(entry_type)) return res.status(400).json({ error: 'Invalid entry_type' });
    if (amount !== undefined && (!Number.isFinite(Number(amount)) || Number(amount) < 0)) return res.status(400).json({ error: 'Invalid amount' });
    if (occurred_at !== undefined && Number.isNaN(Date.parse(occurred_at))) return res.status(400).json({ error: 'Invalid occurred_at' });
    if (client_id && !await requireClientAccess(req, res, businessId, client_id)) return;
    const fields = [];
    const values = [];
    const add = (field, value) => { values.push(value); fields.push(`${field} = $${values.length}`); };
    if (entry_type !== undefined) add('entry_type', entry_type);
    if (amount !== undefined) add('amount', amount);
    if (description !== undefined) add('description', String(description).trim());
    if (client_id !== undefined) add('client_id', client_id || null);
    if (occurred_at !== undefined) add('occurred_at', occurred_at);
    if (fields.length === 0) return res.status(400).json({ error: 'No supported fields supplied' });
    values.push(entryId, businessId);
    const result = await pool.query(
      `UPDATE administrative_financial_entries SET ${fields.join(', ')}
       WHERE id = $${values.length - 1} AND business_id = $${values.length} RETURNING *`,
      values,
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Financial entry not found' });
    const entry = result.rows[0];
    await logActivity(businessId, req.user.id, 'financial_entry_updated', 'financial_entry', entry.id, entry.client_id);
    res.json(entry);
  }));

  router.get('/:businessId/invoices', requireManager, asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { status, clientId, limit = '100', offset = '0' } = req.query;
    const params = [businessId];
    let query = `SELECT i.*, c.name AS client_name
                 FROM administrative_invoices i
                 JOIN administrative_clients c ON c.id = i.client_id
                 WHERE i.business_id = $1`;
    if (status) { params.push(status); query += ` AND i.status = $${params.length}`; }
    if (clientId) { params.push(clientId); query += ` AND i.client_id = $${params.length}`; }
    params.push(Math.min(200, Math.max(1, Number(limit) || 100)), Math.max(0, Number(offset) || 0));
    query += ` ORDER BY i.created_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`;
    const result = await pool.query(query, params);
    res.json({ data: result.rows });
  }));

  router.get('/:businessId/invoices/:invoiceId', requireManager, asyncHandler(async (req, res) => {
    const { businessId, invoiceId } = req.params;
    const invoiceResult = await pool.query(
      `SELECT i.*, c.name AS client_name
       FROM administrative_invoices i
       JOIN administrative_clients c ON c.id = i.client_id
       WHERE i.id = $1 AND i.business_id = $2`,
      [invoiceId, businessId],
    );
    const invoice = invoiceResult.rows[0];
    if (!invoice) return res.status(404).json({ error: 'Invoice not found' });
    const items = await pool.query(
      'SELECT * FROM administrative_invoice_items WHERE invoice_id = $1 ORDER BY created_at ASC',
      [invoiceId],
    );
    res.json({ ...invoice, items: items.rows });
  }));

  router.post('/:businessId/invoices', requireManager, requireFields('client_id', 'invoice_number', 'items'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { client_id, invoice_number, items, due_date, notes, currency = 'NGN', tax_amount = 0 } = req.body;
    if (!Array.isArray(items) || items.length === 0) return res.status(400).json({ error: 'At least one invoice item is required' });
    const client = await requireClientAccess(req, res, businessId, client_id);
    if (!client) return;
    const normalizedItems = items.map((item) => ({
      description: String(item.description || '').trim(),
      quantity: Number(item.quantity),
      unitPrice: Number(item.unit_price),
    }));
    if (normalizedItems.some((item) => !item.description || !Number.isFinite(item.quantity) || item.quantity <= 0 || !Number.isFinite(item.unitPrice) || item.unitPrice < 0)) {
      return res.status(400).json({ error: 'Each invoice item needs a description, positive quantity, and non-negative unit_price' });
    }
    const subtotal = normalizedItems.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);
    const tax = Number(tax_amount);
    if (!Number.isFinite(tax) || tax < 0) return res.status(400).json({ error: 'Invalid tax_amount' });
    const invoiceResult = await pool.query(
      `INSERT INTO administrative_invoices
       (business_id, client_id, invoice_number, currency, due_date, subtotal, tax_amount, total_amount, notes, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING *`,
      [businessId, client_id, invoice_number.trim(), currency, due_date || null, subtotal, tax, subtotal + tax, notes || null, req.user.id],
    );
    const invoice = invoiceResult.rows[0];
    for (const item of normalizedItems) {
      await pool.query(
        `INSERT INTO administrative_invoice_items (invoice_id, description, quantity, unit_price, line_total)
         VALUES ($1, $2, $3, $4, $5)`,
        [invoice.id, item.description, item.quantity, item.unitPrice, item.quantity * item.unitPrice],
      );
    }
    await logActivity(businessId, req.user.id, 'invoice_created', 'invoice', invoice.id, client_id, { invoice_number: invoice.invoice_number });
    res.status(201).json(invoice);
  }));

  router.post('/:businessId/invoices/:invoiceId/send', requireManager, asyncHandler(async (req, res) => {
    const { businessId, invoiceId } = req.params;
    const result = await pool.query(
      `UPDATE administrative_invoices SET status = 'sent', sent_at = NOW(), updated_at = NOW()
       WHERE id = $1 AND business_id = $2 AND status = 'draft' RETURNING *`,
      [invoiceId, businessId],
    );
    if (result.rows.length === 0) return res.status(409).json({ error: 'Only draft invoices can be sent' });
    const invoice = result.rows[0];
    await logActivity(businessId, req.user.id, 'invoice_sent', 'invoice', invoice.id, invoice.client_id);
    res.json(invoice);
  }));

  router.post('/:businessId/invoices/:invoiceId/email', requireManager, requireFields('email'), asyncHandler(async (req, res) => {
    if (!sendMail) return res.status(503).json({ error: 'Invoice email delivery is not configured' });
    const { businessId, invoiceId } = req.params;
    const email = String(req.body.email || '').trim();
    if (!/^\S+@\S+\.\S+$/.test(email)) return res.status(400).json({ error: 'A valid email is required' });
    const result = await pool.query(
      `SELECT i.*, c.name AS client_name FROM administrative_invoices i
       JOIN administrative_clients c ON c.id = i.client_id
       WHERE i.id = $1 AND i.business_id = $2`,
      [invoiceId, businessId],
    );
    const invoice = result.rows[0];
    if (!invoice) return res.status(404).json({ error: 'Invoice not found' });
    const items = await pool.query('SELECT description, quantity, line_total FROM administrative_invoice_items WHERE invoice_id = $1', [invoiceId]);
    const lines = items.rows.map((item) => `<tr><td>${String(item.description).replace(/[&<>]/g, '')}</td><td>${item.quantity}</td><td>${item.line_total}</td></tr>`).join('');
    await sendMail({
      to: email,
      subject: `Invoice ${invoice.invoice_number}`,
      html: `<h2>Invoice ${invoice.invoice_number}</h2><p>Client: ${invoice.client_name}</p><table><tr><th>Description</th><th>Qty</th><th>Amount</th></tr>${lines}</table><p><strong>Total: ${invoice.currency} ${invoice.total_amount}</strong></p>`,
    });
    if (invoice.status === 'draft') {
      await pool.query("UPDATE administrative_invoices SET status = 'sent', sent_at = NOW(), updated_at = NOW() WHERE id = $1", [invoiceId]);
    }
    await logActivity(businessId, req.user.id, 'invoice_emailed', 'invoice', invoiceId, invoice.client_id, { email });
    res.json({ delivered: true });
  }));

  router.post('/:businessId/invoices/:invoiceId/void', requireManager, asyncHandler(async (req, res) => {
    const { businessId, invoiceId } = req.params;
    const result = await pool.query(
      `UPDATE administrative_invoices SET status = 'void', updated_at = NOW()
       WHERE id = $1 AND business_id = $2 AND status IN ('draft', 'sent') RETURNING *`,
      [invoiceId, businessId],
    );
    if (result.rows.length === 0) return res.status(409).json({ error: 'Only unpaid invoices can be voided' });
    const invoice = result.rows[0];
    await logActivity(businessId, req.user.id, 'invoice_voided', 'invoice', invoice.id, invoice.client_id);
    res.json(invoice);
  }));

  router.post('/:businessId/invoices/:invoiceId/payments', requireManager, requireFields('amount'), asyncHandler(async (req, res) => {
    const { businessId, invoiceId } = req.params;
    const amount = Number(req.body.amount);
    if (!Number.isFinite(amount) || amount <= 0) return res.status(400).json({ error: 'Payment amount must be positive' });
    const db = await pool.connect();
    let updated;
    try {
      await db.query('BEGIN');
      const existing = await db.query('SELECT * FROM administrative_invoices WHERE id = $1 AND business_id = $2 FOR UPDATE', [invoiceId, businessId]);
      const invoice = existing.rows[0];
      if (!invoice || !['sent', 'paid'].includes(invoice.status)) {
        await db.query('ROLLBACK');
        return res.status(409).json({ error: 'Only sent invoices can receive payments' });
      }
      if (Number(invoice.paid_amount) + amount > Number(invoice.total_amount)) {
        await db.query('ROLLBACK');
        return res.status(400).json({ error: 'Payment exceeds outstanding invoice balance' });
      }
      const paidAmount = Number(invoice.paid_amount) + amount;
      const paidInFull = paidAmount >= Number(invoice.total_amount);
      const updatedResult = await db.query(
        `UPDATE administrative_invoices
         SET paid_amount = $1, status = $2, paid_at = CASE WHEN $2 = 'paid' THEN NOW() ELSE paid_at END, updated_at = NOW()
         WHERE id = $3 RETURNING *`,
        [paidAmount, paidInFull ? 'paid' : 'sent', invoiceId],
      );
      updated = updatedResult.rows[0];
      await db.query(
        `INSERT INTO administrative_financial_entries (business_id, client_id, invoice_id, entry_type, amount, description, created_by)
         VALUES ($1, $2, $3, 'revenue', $4, $5, $6)`,
        [businessId, updated.client_id, invoiceId, amount, `Invoice payment ${updated.invoice_number}`, req.user.id],
      );
      await db.query('COMMIT');
    } catch (error) {
      await db.query('ROLLBACK');
      throw error;
    } finally {
      db.release();
    }
    await logActivity(businessId, req.user.id, 'invoice_payment_recorded', 'invoice', invoiceId, updated.client_id, { amount });
    res.json(updated);
  }));

  router.get('/:businessId/tasks', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { status, assignedTo, clientId } = req.query;
    const params = [businessId];
    let query = `SELECT t.*, c.name AS client_name, d.file_name AS document_name,
                        w.full_name AS assigned_worker_name
                 FROM administrative_tasks t
                 LEFT JOIN administrative_clients c ON c.id = t.client_id
                 LEFT JOIN administrative_documents d ON d.id = t.document_id
                 LEFT JOIN workers w ON w.id = t.assigned_to
                 WHERE t.business_id = $1`;
    if (status) { params.push(status); query += ` AND t.status = $${params.length}`; }
    if (clientId) { params.push(clientId); query += ` AND t.client_id = $${params.length}`; }
    if (assignedTo) {
      if (!isManager(req) && assignedTo !== req.user.id) return res.status(403).json({ error: 'You can only view your own tasks' });
      params.push(assignedTo);
      query += ` AND t.assigned_to = $${params.length}`;
    } else if (!isManager(req)) {
      params.push(req.user.id);
      query += ` AND t.assigned_to = $${params.length}`;
    }
    query += ' ORDER BY t.due_at NULLS LAST, t.created_at DESC';
    const result = await pool.query(query, params);
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/tasks', requireManager, requireFields('title'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { client_id, document_id, title, remark, assigned_to, due_at, priority = 'normal' } = req.body;
    if (!['low', 'normal', 'high', 'urgent'].includes(priority)) return res.status(400).json({ error: 'Invalid task priority' });
    if (client_id && !await requireClientAccess(req, res, businessId, client_id)) return;
    if (document_id) {
      const document = await pool.query('SELECT id, client_id FROM administrative_documents WHERE id = $1 AND business_id = $2', [document_id, businessId]);
      if (document.rows.length === 0) return res.status(400).json({ error: 'Document not found for this business' });
      if (client_id && document.rows[0].client_id !== client_id) return res.status(400).json({ error: 'Document does not belong to this client' });
    }
    if (assigned_to) {
      const worker = await pool.query('SELECT id FROM workers WHERE id = $1 AND business_id = $2 AND is_active = true', [assigned_to, businessId]);
      if (worker.rows.length === 0) return res.status(400).json({ error: 'Active worker not found' });
      if (client_id) {
        const permitted = await pool.query('SELECT 1 FROM administrative_client_workers WHERE client_id = $1 AND worker_id = $2', [client_id, assigned_to]);
        if (permitted.rows.length === 0) return res.status(400).json({ error: 'Worker is not assigned to this client' });
      }
    }
    const result = await pool.query(
      `INSERT INTO administrative_tasks
       (business_id, client_id, document_id, title, remark, assigned_to, assigned_by, due_at, priority)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [businessId, client_id || null, document_id || null, title.trim(), remark || null, assigned_to || null, req.user.id, due_at || null, priority],
    );
    const task = result.rows[0];
    await logActivity(businessId, req.user.id, 'task_assigned', 'task', task.id, task.client_id, { assigned_to: task.assigned_to });
    res.status(201).json(task);
  }));

  router.get('/:businessId/tasks/:taskId/comments', asyncHandler(async (req, res) => {
    const { businessId, taskId } = req.params;
    const taskResult = await pool.query('SELECT * FROM administrative_tasks WHERE id = $1 AND business_id = $2', [taskId, businessId]);
    const task = taskResult.rows[0];
    if (!task) return res.status(404).json({ error: 'Task not found' });
    if (!isManager(req) && task.assigned_to !== req.user.id) return res.status(403).json({ error: 'Task access is required' });
    const result = await pool.query(
      `SELECT c.*, p.full_name AS author_name
       FROM administrative_task_comments c
       LEFT JOIN profiles p ON p.id = c.author_id
       WHERE c.task_id = $1 ORDER BY c.created_at ASC`,
      [taskId],
    );
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/tasks/:taskId/comments', requireFields('body'), asyncHandler(async (req, res) => {
    const { businessId, taskId } = req.params;
    const taskResult = await pool.query('SELECT * FROM administrative_tasks WHERE id = $1 AND business_id = $2', [taskId, businessId]);
    const task = taskResult.rows[0];
    if (!task) return res.status(404).json({ error: 'Task not found' });
    if (!isManager(req) && task.assigned_to !== req.user.id) return res.status(403).json({ error: 'Task access is required' });
    const result = await pool.query(
      `INSERT INTO administrative_task_comments (task_id, business_id, author_id, body)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [taskId, businessId, req.user.id, req.body.body.trim()],
    );
    const comment = result.rows[0];
    await logActivity(businessId, req.user.id, 'task_comment_added', 'task', taskId, task.client_id);
    res.status(201).json(comment);
  }));

  router.patch('/:businessId/tasks/:taskId/status', requireFields('status'), asyncHandler(async (req, res) => {
    const { businessId, taskId } = req.params;
    const { status, review_action } = req.body;
    const allowed = ['assigned', 'in_progress', 'submitted', 'approved', 'rejected'];
    if (!allowed.includes(status)) return res.status(400).json({ error: 'Invalid task status' });

    const found = await pool.query(
      'SELECT * FROM administrative_tasks WHERE id = $1 AND business_id = $2',
      [taskId, businessId],
    );
    const task = found.rows[0];
    if (!task) return res.status(404).json({ error: 'Task not found' });

    const workerUpdate = ['in_progress', 'submitted'].includes(status);
    const reviewing = ['approved', 'rejected'].includes(status);
    if (workerUpdate && task.assigned_to !== req.user.id) return res.status(403).json({ error: 'Only the assigned worker can update this task' });
    if (reviewing && !isManager(req)) return res.status(403).json({ error: 'Administrative access is required for review' });
    if (!workerUpdate && !reviewing && !isManager(req)) return res.status(403).json({ error: 'Administrative access is required' });
    if (reviewing && !['replace', 'new_version'].includes(review_action || 'replace') && status === 'approved') {
      return res.status(400).json({ error: 'review_action must be replace or new_version' });
    }

    const result = await pool.query(
      `UPDATE administrative_tasks SET
         status = $1,
         completed_at = CASE WHEN $1 = 'submitted' THEN NOW() ELSE completed_at END,
         reviewed_by = CASE WHEN $1 IN ('approved', 'rejected') THEN $2 ELSE reviewed_by END,
         reviewed_at = CASE WHEN $1 IN ('approved', 'rejected') THEN NOW() ELSE reviewed_at END,
         review_action = CASE WHEN $1 = 'approved' THEN $3 ELSE review_action END,
         updated_at = NOW()
       WHERE id = $4 AND business_id = $5
       RETURNING *`,
      [status, req.user.id, status === 'approved' ? review_action || 'replace' : null, taskId, businessId],
    );
    const updated = result.rows[0];
    await logActivity(businessId, req.user.id, `task_${status}`, 'task', updated.id, updated.client_id, { review_action: updated.review_action });
    res.json(updated);
  }));

  router.get('/:businessId/obligations', asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const params = [businessId];
    let query = `SELECT o.*, c.name AS client_name, w.full_name AS assigned_worker_name
                 FROM administrative_obligations o
                 JOIN administrative_clients c ON c.id = o.client_id
                 LEFT JOIN workers w ON w.id = o.assigned_to
                 WHERE o.business_id = $1 AND o.is_active = true`;
    if (!isManager(req)) {
      params.push(req.user.id);
      query += ` AND o.assigned_to = $${params.length}`;
    }
    query += ' ORDER BY o.next_due_at ASC';
    const result = await pool.query(query, params);
    res.json({ data: result.rows });
  }));

  router.post('/:businessId/obligations', requireManager, requireFields('client_id', 'title', 'recurrence_type', 'interval_days'), asyncHandler(async (req, res) => {
    const { businessId } = req.params;
    const { client_id, title, recurrence_type, interval_days, fixed_day_of_month, assigned_to } = req.body;
    if (!['fixed', 'trailing'].includes(recurrence_type)) return res.status(400).json({ error: 'recurrence_type must be fixed or trailing' });
    if (!Number.isInteger(Number(interval_days)) || Number(interval_days) < 1) return res.status(400).json({ error: 'interval_days must be a positive integer' });
    if (recurrence_type === 'fixed' && (!Number.isInteger(Number(fixed_day_of_month)) || Number(fixed_day_of_month) < 1 || Number(fixed_day_of_month) > 31)) {
      return res.status(400).json({ error: 'fixed_day_of_month must be between 1 and 31' });
    }
    const now = new Date();
    const nextDueAt = recurrence_type === 'fixed'
      ? nextFixedDate(now, fixed_day_of_month)
      : new Date(now.getTime() + Number(interval_days) * 86400000);
    const result = await pool.query(
      `INSERT INTO administrative_obligations
       (business_id, client_id, title, recurrence_type, interval_days, fixed_day_of_month, next_due_at, assigned_to, created_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [businessId, client_id, title.trim(), recurrence_type, interval_days, fixed_day_of_month || null, nextDueAt, assigned_to || null, req.user.id],
    );
    const obligation = result.rows[0];
    await logActivity(businessId, req.user.id, 'obligation_created', 'obligation', obligation.id, obligation.client_id);
    res.status(201).json(obligation);
  }));

  router.post('/:businessId/obligations/:obligationId/complete', asyncHandler(async (req, res) => {
    const { businessId, obligationId } = req.params;
    const found = await pool.query(
      'SELECT * FROM administrative_obligations WHERE id = $1 AND business_id = $2 AND is_active = true',
      [obligationId, businessId],
    );
    const obligation = found.rows[0];
    if (!obligation) return res.status(404).json({ error: 'Obligation not found' });
    if (!isManager(req) && obligation.assigned_to !== req.user.id) return res.status(403).json({ error: 'Only the assigned worker can complete this obligation' });
    const now = new Date();
    const nextDueAt = obligation.recurrence_type === 'fixed'
      ? nextFixedDate(now, obligation.fixed_day_of_month)
      : new Date(now.getTime() + Number(obligation.interval_days) * 86400000);
    const result = await pool.query(
      `UPDATE administrative_obligations
       SET last_completed_at = NOW(), next_due_at = $1, updated_at = NOW()
       WHERE id = $2 AND business_id = $3
       RETURNING *`,
      [nextDueAt, obligationId, businessId],
    );
    const updated = result.rows[0];
    await logActivity(businessId, req.user.id, 'obligation_completed', 'obligation', updated.id, updated.client_id, { next_due_at: updated.next_due_at });
    res.json(updated);
  }));

  return router;
};
