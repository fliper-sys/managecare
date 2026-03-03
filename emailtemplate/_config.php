<?php
// Centralized configuration used by the emailtemplate endpoints for testing.
// Replace these values or unset them and use environment variables in production.

// Legacy API key used by clients (temporary test value)
$API_KEY = '8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef';

// SMTP settings (used by mail.php)
$SMTP_HOST = 'smtp.hostinger.com';
$SMTP_USER = 'mc@globalthrivealliance.com';
$SMTP_PASS = 'Xanther839@';
$SMTP_PORT = 587;
$SMTP_SECURE = 'tls';
// Default From address/name (can be overridden by env vars)
$SMTP_FROM = getenv('SMTP_FROM') ?: 'mc@globalthrivealliance.com';
$SMTP_FROM_NAME = getenv('SMTP_FROM_NAME') ?: 'Manage Care';

// Optional tokens, read from env if available
$DAILY_REPORT_API_KEY = getenv('DAILY_REPORT_API_KEY') ?: '';
$DAILY_REPORT_HOOK_TOKEN = getenv('DAILY_REPORT_HOOK_TOKEN') ?: '';

// Note: DO NOT commit production secrets. Remove or rotate these test values after verification.
?>