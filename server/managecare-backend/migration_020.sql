-- Pharmacy vertical. Drugs are just inventory items (already covered by the
-- `inventory` table/routes) plus a few pharmacy-only fields that don't fit
-- the generic inventory schema - those go in a new generic `metadata` JSONB
-- column so other verticals can reuse the same escape hatch instead of each
-- needing their own ALTER TABLE.
ALTER TABLE inventory ADD COLUMN IF NOT EXISTS metadata JSONB NOT NULL DEFAULT '{}';

CREATE TABLE IF NOT EXISTS pharmacy_patients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT,
  email TEXT,
  address TEXT,
  date_of_birth TIMESTAMPTZ,
  allergies TEXT,
  blood_type TEXT,
  additional_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pharmacy_patients_business_id ON pharmacy_patients(business_id);

CREATE TABLE IF NOT EXISTS pharmacy_prescriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  patient_id UUID REFERENCES pharmacy_patients(id) ON DELETE SET NULL,
  patient_name TEXT,
  items JSONB NOT NULL DEFAULT '[]',
  status TEXT NOT NULL DEFAULT 'pending',
  prescriber_id UUID,
  prescriber_name TEXT,
  notes TEXT,
  attachment_reference TEXT,
  attachment_required BOOLEAN NOT NULL DEFAULT false,
  patient_date_of_birth TIMESTAMPTZ,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pharmacy_prescriptions_business_id ON pharmacy_prescriptions(business_id);

CREATE TABLE IF NOT EXISTS pharmacy_treatments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  patient_id UUID,
  name TEXT NOT NULL,
  drug_name TEXT,
  dosage TEXT,
  frequency_per_day INTEGER NOT NULL DEFAULT 1,
  duration_days INTEGER NOT NULL DEFAULT 1,
  start_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  end_date TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT true,
  administered_log JSONB NOT NULL DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pharmacy_treatments_business_id ON pharmacy_treatments(business_id);

-- Audit trail for controlled-substance-involving actions
-- (PharmacyProvider.logAudit).
CREATE TABLE IF NOT EXISTS pharmacy_audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE,
  action TEXT,
  actor_id UUID,
  details JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_pharmacy_audit_log_business_id ON pharmacy_audit_log(business_id);
