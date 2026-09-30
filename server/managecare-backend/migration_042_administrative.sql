-- Administrative Services workspace: clients, document work, deadlines, and audit history.

CREATE TABLE IF NOT EXISTS administrative_clients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  company_name TEXT,
  location TEXT,
  contact_address TEXT,
  portal_credentials JSONB NOT NULL DEFAULT '[]',
  revenue_access_pin_hash TEXT,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS administrative_client_workers (
  client_id UUID NOT NULL REFERENCES administrative_clients(id) ON DELETE CASCADE,
  worker_id UUID NOT NULL REFERENCES workers(id) ON DELETE CASCADE,
  assigned_by UUID REFERENCES profiles(id),
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (client_id, worker_id)
);

CREATE TABLE IF NOT EXISTS administrative_document_folders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES administrative_clients(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (client_id, name)
);

CREATE TABLE IF NOT EXISTS administrative_documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES administrative_clients(id) ON DELETE CASCADE,
  folder_id UUID REFERENCES administrative_document_folders(id) ON DELETE SET NULL,
  file_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  file_size_bytes BIGINT,
  mime_type TEXT,
  status TEXT NOT NULL DEFAULT 'stored',
  uploaded_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS administrative_tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  client_id UUID REFERENCES administrative_clients(id) ON DELETE CASCADE,
  document_id UUID REFERENCES administrative_documents(id) ON DELETE SET NULL,
  title TEXT NOT NULL,
  remark TEXT,
  assigned_to UUID REFERENCES workers(id) ON DELETE SET NULL,
  assigned_by UUID REFERENCES profiles(id),
  due_at TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'assigned',
  completed_at TIMESTAMPTZ,
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  review_action TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS administrative_obligations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES administrative_clients(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  recurrence_type TEXT NOT NULL CHECK (recurrence_type IN ('fixed', 'trailing')),
  interval_days INTEGER NOT NULL CHECK (interval_days > 0),
  fixed_day_of_month INTEGER CHECK (fixed_day_of_month BETWEEN 1 AND 31),
  next_due_at TIMESTAMPTZ NOT NULL,
  last_completed_at TIMESTAMPTZ,
  assigned_to UUID REFERENCES workers(id) ON DELETE SET NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS administrative_activity_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  client_id UUID REFERENCES administrative_clients(id) ON DELETE SET NULL,
  actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  metadata JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS administrative_clients_business_idx ON administrative_clients (business_id);
CREATE INDEX IF NOT EXISTS administrative_documents_client_idx ON administrative_documents (client_id, folder_id);
CREATE INDEX IF NOT EXISTS administrative_tasks_assignee_idx ON administrative_tasks (assigned_to, due_at);
CREATE INDEX IF NOT EXISTS administrative_obligations_due_idx ON administrative_obligations (business_id, next_due_at);
CREATE INDEX IF NOT EXISTS administrative_activity_business_idx ON administrative_activity_log (business_id, created_at DESC);
