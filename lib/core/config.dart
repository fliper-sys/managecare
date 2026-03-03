/// App configuration (temporary hard-coded credentials)
/// NOTE: Storing secrets in source code is insecure. This is provided
/// per user request for quick testing only. Move to secure server/storage.
library;

class AppConfig {
  // WhatsApp Cloud API (Meta) credentials
  // Replace these values with your test credentials
  // Provided by user (temporary hard-coded values)
  static const String whatsappPhoneNumberId =
      '1568870394531156'; // app id / phone number id
  static const String whatsappAccessToken =
      'EAAWS4RqQjVQBQJEmB4zSEeIIP17yY3zq6NZBZBaGyAgyzSGLwXr697HCsSgjMggZAjsHoj1e7ySeqAXTAL4ehDVZCZACX7wUFoGEdxKIth1RXMJpAv0DBra1MTjV2ZALKJJrxoKb8I63GKXbzycgIwr1lNT6YVZAZBlzpTSoaRatW7btPgFhrzamoGYYbRWKf3V08EVY6h8YT8ZAe2C71ZCtjnpT9c49JyN6ZCgAcAQ9SddzJU0j8BeLY6Uc60b7fxZCL3jnunOrQZAxCKZCqqGRE3eAiL'; // app secret / access token
  static const String ownerWhatsappNumber = '+2348063124936';

  // Daily report trigger defaults - configure these for your server
  // NOTE: storing API keys in source is insecure — prefer server-side hooks or remote config.
  static const String dailyReportTriggerUrl = ''; // e.g. 'https://example.com/emailtemplate/trigger_daily_send.php'
  static const String dailyReportApiKey = ''; // optional API key used when calling trigger endpoint from app
  static const String dailyReportHookToken = ''; // optional X-Hook-Token header value
}

