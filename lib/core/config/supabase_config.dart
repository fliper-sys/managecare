/// Self-hosted Supabase stack configuration.
///
/// ANON_KEY is a public, client-embeddable credential by design (identical in
/// spirit to Firebase's web API key) - it is meaningless without Row Level
/// Security policies enforcing access, which live in the database itself.
/// SUPABASE_SERVICE_ROLE_KEY must NEVER appear here or anywhere client-side;
/// it lives only in the managecare-admin-api service's environment on the VPS.
class SupabaseConfig {
  static const String url = 'https://backend.managecare.info';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzg0NzgzMjk1LCJleHAiOjE5NDI0NjMyOTV9.HHWZ2RDWtJNuyoRgiJwMzPf7CbKtQFbsykkdLZNPO-w';

  /// Base URL for the custom privileged endpoints (worker create/delete/resolve)
  /// that require the service-role key and therefore cannot run client-side.
  static const String adminApiUrl = 'https://backend.managecare.info/admin-api';
}
