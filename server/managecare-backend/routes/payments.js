/**
 * Kora payment gateway routes for ManageCare, replacing the Firebase Cloud
 * Functions initializeKoraSubscriptionPayment/verifyKoraSubscriptionPayment.
 * The secret key stays server-side in process.env, never sent to the client.
 */
const express = require('express');
const router = express.Router();
const { asyncHandler, requireFields } = require('../middleware/validation');

const ALLOWED_CHANNELS = new Set(['card', 'bank_transfer', 'pay_with_bank', 'mobile_money']);

function resolveChannels(rawChannels) {
  const channels = Array.isArray(rawChannels)
    ? rawChannels.map((c) => c.toString().trim()).filter(Boolean)
    : [];
  const filtered = channels.filter((c) => ALLOWED_CHANNELS.has(c));
  return filtered.length > 0 ? filtered : ['bank_transfer'];
}

function normalizeReference(rawReference, userId) {
  const cleaned = (rawReference || '').toString().trim().replace(/[^a-zA-Z0-9_-]/g, '_');
  if (cleaned && cleaned.length <= 50) return cleaned;

  const lower = cleaned.toLowerCase();
  const prefix = lower.startsWith('kora_gym') ? 'kgym' : lower.startsWith('kora_sub') ? 'ksub' : 'kora';
  const uidPart = (userId || 'user').toString().replace(/[^a-zA-Z0-9]/g, '').slice(0, 10) || 'user';
  const timePart = Date.now().toString(36);
  const randomPart = Math.random().toString(36).slice(2, 8);
  return `${prefix}_${uidPart}_${timePart}${randomPart}`.slice(0, 50);
}

function getKoraErrorMessage(payload, fallback) {
  const data = payload && typeof payload === 'object' ? payload.data : null;
  if (data && typeof data === 'object') {
    for (const value of Object.values(data)) {
      if (value && typeof value === 'object') {
        if (value.customErrorMessage) return value.customErrorMessage.toString();
        if (value.message) return value.message.toString();
      }
    }
  }
  return (payload && payload.message ? payload.message : fallback).toString();
}

module.exports = function() {
  function requireKoraSecret(req, res, next) {
    if (!process.env.KORA_SECRET_KEY) {
      return res.status(503).json({ error: 'Kora payment gateway is not configured' });
    }
    next();
  }

  router.post('/kora/initialize', requireKoraSecret, requireFields('reference', 'amount', 'email', 'fullName', 'redirectUrl'), asyncHandler(async (req, res) => {
    const {
      reference: rawReference, amount, currency, email, fullName, redirectUrl,
      planId, businessId, userId, channels: rawChannels, recurringEnabled, recurrenceInterval,
    } = req.body;

    const reference = normalizeReference(rawReference, userId || req.user?.id);
    const channels = resolveChannels(rawChannels);
    const metadata = {
      planId: planId || '',
      businessId: businessId || '',
      userId: userId || req.user?.id || '',
      recurringEnabled: recurringEnabled === true ? 'true' : 'false',
    };
    if (recurringEnabled === true) {
      metadata.recurrenceInterval = recurrenceInterval || 'plan_duration';
    } else {
      metadata.selectedChannels = channels.join(',');
    }

    const response = await fetch('https://api.korapay.com/merchant/api/v1/charges/initialize', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${process.env.KORA_SECRET_KEY}`,
      },
      body: JSON.stringify({
        amount: Number(amount),
        currency: (currency || 'NGN').toUpperCase(),
        reference,
        channels,
        redirect_url: redirectUrl,
        customer: { name: fullName, email },
        notification_url: redirectUrl,
        metadata,
      }),
    });

    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      console.error('[kora/initialize] failed', payload);
      return res.status(response.status === 400 ? 400 : 502).json({
        error: getKoraErrorMessage(payload, 'Failed to initialize Kora payment'),
      });
    }

    const checkoutUrl = payload?.data?.checkout_url || payload?.data?.checkoutUrl
      || payload?.data?.link || payload?.data?.url;
    if (!checkoutUrl) {
      console.error('[kora/initialize] missing checkout URL', payload);
      return res.status(502).json({ error: 'Kora did not return a checkout URL' });
    }

    res.json({ success: true, checkoutUrl, reference, redirectUrl });
  }));

  router.post('/transactions', requireFields('transactionId', 'amount', 'method'), asyncHandler(async (req, res) => {
    const {
      transactionId, businessId, businessName, amount, currency, email,
      method, status, businessCategory, businessTier, processorResponse,
    } = req.body;

    const result = await pool.query(`
      INSERT INTO payment_transactions
        (business_id, business_name, transaction_id, amount, currency, email, method,
         status, business_category, business_tier, processor_response)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, COALESCE($11::jsonb, '{}'::jsonb))
      RETURNING *
    `, [
      businessId || null, businessName || null, transactionId, amount,
      currency || 'NGN', email || null, method, status || 'completed',
      businessCategory || null, businessTier || null,
      processorResponse ? JSON.stringify(processorResponse) : null,
    ]);
    res.status(201).json(result.rows[0]);
  }));

  router.post('/kora/verify', requireKoraSecret, requireFields('reference'), asyncHandler(async (req, res) => {
    const { reference } = req.body;

    const response = await fetch(`https://api.korapay.com/merchant/api/v1/charges/${encodeURIComponent(reference)}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${process.env.KORA_SECRET_KEY}`,
      },
    });

    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      console.error('[kora/verify] failed', payload);
      return res.status(502).json({ error: payload.message || 'Failed to verify Kora payment' });
    }

    const paymentData = payload?.data || {};
    const rawStatus = (
      paymentData.status || paymentData.payment_status || paymentData.charge_status || payload.status || ''
    ).toString().toLowerCase();
    const successStatuses = new Set(['success', 'successful', 'paid', 'completed']);
    const isSuccessful = successStatuses.has(rawStatus);

    res.json({
      success: isSuccessful,
      message: isSuccessful ? 'Payment verified successfully' : (payload.message || 'Payment has not been completed successfully'),
      reference,
      status: rawStatus || 'unknown',
      paymentMethod: (paymentData.payment_method || paymentData.channel || paymentData.method || 'kora').toString(),
      raw: payload,
    });
  }));

  return router;
};
