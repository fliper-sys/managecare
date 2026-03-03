<?php
// trigger_daily_send.php
// Lightweight webhook endpoint to accept transaction summaries and send daily report to owner
// Expected POST JSON payload (same as WhatsAppService webhook):
// { businessId, businessName, date, total, count, transactions: [...] }

header('Content-Type: application/json');
$autoload = __DIR__ . '/vendor/autoload.php';
if (file_exists($autoload)) {
    require $autoload;
} else {
    // Composer autoload not present; proceed without vendor packages.
    // This endpoint doesn't require composer unless you add third-party libraries.
    error_log("[trigger_daily_send] Warning: composer autoload not found at $autoload; continuing without vendor packages.");
}

$apiKey = getenv('DAILY_REPORT_API_KEY') ?: '';
$expectedHookToken = getenv('DAILY_REPORT_HOOK_TOKEN') ?: null; // optional

function respond($statusCode, $payload) {
    http_response_code($statusCode);
    echo json_encode($payload);
    exit;
}

// Allow only POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    respond(405, ['ok' => false, 'error' => 'method_not_allowed']);
}

$raw = file_get_contents('php://input');

// Accept JSON body or form-encoded POST (for legacy clients that send api_key via form)
if (!empty($raw)) {
    $data = json_decode($raw, true);
    if (!is_array($data)) {
        respond(400, ['ok' => false, 'error' => 'invalid_json']);
    }
} else if (!empty($_POST)) {
    // Normalize form values into $data array
    $data = $_POST;
    if (isset($data['transactions']) && is_string($data['transactions'])) {
        $decoded = json_decode($data['transactions'], true);
        if (is_array($decoded)) $data['transactions'] = $decoded;
    }
} else {
    respond(400, ['ok' => false, 'error' => 'empty_body']);
}

$businessId = $data['businessId'] ?? '';
$transactions = is_array($data['transactions']) ? $data['transactions'] : [];
$reportDate = $data['date'] ?? date('Y-m-d');

if (empty($businessId)) {
    respond(400, ['ok' => false, 'error' => 'missing_businessId']);
}

// If a hook token is configured, require header match
$hookToken = $_SERVER['HTTP_X_HOOK_TOKEN'] ?? null;
$authorizedByHook = false;
if ($expectedHookToken !== null && $expectedHookToken !== '') {
    if (!empty($hookToken) && hash_equals($expectedHookToken, $hookToken)) {
        $authorizedByHook = true;
    } else {
        respond(403, ['ok' => false, 'error' => 'invalid_hook_token']);
    }
}

// Allow legacy or explicit api_key in POST or X-API-KEY header to authorize the request
require_once __DIR__ . '/_config.php';
$providedKey = $data['api_key'] ?? ($_SERVER['HTTP_X_API_KEY'] ?? null);
$legacyKey = $API_KEY;
$authorizedByKey = false;
if (!empty($providedKey)) {
    if ((!empty($apiKey) && hash_equals($apiKey, $providedKey)) || $providedKey === $legacyKey) {
        $authorizedByKey = true;
    }
}

// If server not configured with DAILY_REPORT_API_KEY, accept payload but save locally for manual processing
if (empty($apiKey)) {
    $logDir = __DIR__ . '/logs';
    if (!is_dir($logDir)) mkdir($logDir, 0755, true);
    $file = $logDir . "/trigger_payload_{$businessId}_{$reportDate}.json";
    file_put_contents($file, json_encode($data, JSON_PRETTY_PRINT));
    respond(202, ['ok' => true, 'status' => 'saved', 'path' => $file]);
}

// Require either hook authorization or valid api_key
if (!($authorizedByHook || $authorizedByKey)) {
    respond(403, ['ok' => false, 'error' => 'unauthorized']);
}

// Build payload for send endpoint
$sendPayload = [
    'recipient' => $data['ownerEmail'] ?? $data['recipient'] ?? '',
    'businessName' => $data['businessName'] ?? '',
    'reportDate' => $reportDate,
    'currency' => $data['currency'] ?? '₦',
    'transactions' => $transactions,
    'totals' => [
        'totalAmount' => $data['total'] ?? array_sum(array_map(function($t){ return floatval($t['amount'] ?? 0); }, $transactions)),
        'totalTransactions' => count($transactions),
    ],
    'attachPdf' => $data['attachPdf'] ?? false,
];

$endpoint = (getenv('DAILY_REPORT_ENDPOINT') ?: rtrim((isset($_SERVER['REQUEST_SCHEME']) ? $_SERVER['REQUEST_SCHEME'] : 'https') . '://' . ($_SERVER['HTTP_HOST'] ?? 'localhost'), '/') . '/emailtemplate/send_daily_sales_report.php');

$ch = curl_init($endpoint);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'X-API-KEY: ' . $apiKey,
]);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($sendPayload));
curl_setopt($ch, CURLOPT_TIMEOUT, 30);

$resp = curl_exec($ch);
$err = curl_error($ch);
$status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($err) {
    respond(502, ['ok' => false, 'error' => 'curl_error', 'message' => $err]);
}

if ($status !== 200) {
    respond($status, ['ok' => false, 'error' => 'send_endpoint_error', 'response' => $resp]);
}

$respData = json_decode($resp, true);
if (!is_array($respData) || !($respData['ok'] ?? false)) {
    respond(500, ['ok' => false, 'error' => 'send_failed', 'response' => $resp]);
}

respond(200, ['ok' => true, 'message' => 'report_triggered']);
