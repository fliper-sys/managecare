const HOSPITALITY_LIMITS = {
  tier1: { rooms: 15, suites: 0, workers: 7, restaurant_tables: 10, bar_tables: 15, branches: 0 },
  tier2: { rooms: 25, suites: 5, workers: 15, restaurant_tables: 20, bar_tables: 25, branches: 1 },
  tier3: { rooms: 40, suites: 10, workers: 25, restaurant_tables: 30, bar_tables: 35, branches: 2 },
  unlimited: { rooms: null, suites: null, workers: null, restaurant_tables: null, bar_tables: null, branches: null },
};

const COUNT_QUERIES = {
  rooms: `SELECT COUNT(*)::int AS count FROM hotel_rooms
          WHERE business_id = $1 AND LOWER(COALESCE(type, '')) <> 'suite'`,
  suites: `SELECT COUNT(*)::int AS count FROM hotel_rooms
           WHERE business_id = $1 AND LOWER(COALESCE(type, '')) = 'suite'`,
  workers: `SELECT COUNT(*)::int AS count FROM workers
            WHERE business_id = $1 AND COALESCE(is_active, true) = true`,
  restaurant_tables: 'SELECT COUNT(*)::int AS count FROM restaurant_tables WHERE business_id = $1',
  bar_tables: 'SELECT COUNT(*)::int AS count FROM bar_tables WHERE business_id = $1',
  branches: 'SELECT COUNT(*)::int AS count FROM stores WHERE business_id = $1 AND is_active = true',
};

function isHospitalityBusinessType(value) {
  const type = String(value || '').trim().toLowerCase().split('/').pop().replaceAll('_', ' ');
  return new Set([
    'hotel', 'hospitality', 'hospitality business', 'apartment',
    'guest inn', 'guesthouse', 'lodge',
  ]).has(type);
}

function resolveTier(business) {
  const allowed = new Set(Object.keys(HOSPITALITY_LIMITS));
  const storedTier = String(business.subscription_tier || '').trim().toLowerCase();
  if (allowed.has(storedTier)) return storedTier;
  const tierAliases = {
    t1: 'tier1',
    t2: 'tier2',
    t3: 'tier3',
    basic: 'tier1',
    starter: 'tier1',
    pro: 'tier3',
    professional: 'tier3',
    premium: 'tier3',
    enterprise: 'unlimited',
  };
  if (tierAliases[storedTier]) return tierAliases[storedTier];

  const plan = String(business.subscription_plan || '').trim().toLowerCase();
  const match = `${storedTier} ${plan}`.match(/(?:^|[_-])(tier[123]|unlimited)(?:[_-]|$)/);
  return match ? match[1] : 'tier1';
}

async function getHospitalityQuota(pool, businessId, resource) {
  const countQuery = COUNT_QUERIES[resource];
  if (!countQuery) throw new Error(`Unknown Hospitality quota resource: ${resource}`);

  const businessResult = await pool.query(
    'SELECT business_type, subscription_tier, subscription_plan FROM businesses WHERE id = $1',
    [businessId],
  );
  const business = businessResult.rows[0];
  if (!business || !isHospitalityBusinessType(business.business_type)) return null;

  const tier = resolveTier(business);
  const limit = HOSPITALITY_LIMITS[tier][resource];
  if (limit == null) return { limit: null, usage: 0 };

  const countResult = await pool.query(countQuery, [businessId]);
  return { limit, usage: Number(countResult.rows[0]?.count || 0) };
}

function sendQuotaLimit(res, resource, quota) {
  return res.status(409).json({
    error: `Subscription ${resource.replaceAll('_', ' ')} limit reached`,
    limit_type: resource,
    limit: quota.limit,
    current_usage: quota.usage,
  });
}

module.exports = { getHospitalityQuota, sendQuotaLimit };
