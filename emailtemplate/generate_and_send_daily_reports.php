<?php
/**
 * generate_and_send_daily_reports.php
 *
 * Aggregates daily transactions (previous day) per business from Firestore and
 * calls the existing `send_daily_sales_report.php` endpoint to email reports.
 *
 * Requirements:
 *  - composer require google/cloud-firestore
 *  - Set environment variables:
 *      GOOGLE_PROJECT_ID (your GCP project id)
 *      GOOGLE_APPLICATION_CREDENTIALS (path to service account json)
 *      DAILY_REPORT_ENDPOINT (e.g. https://your-server.com/emailtemplate/send_daily_sales_report.php)
 *      DAILY_REPORT_API_KEY (API key expected by the send endpoint)
 *
 * Usage (cron job example):
 * 0 2 * * * /usr/bin/php /path/to/emailtemplate/generate_and_send_daily_reports.php >> /var/log/daily_sales_reports.log 2>&1
 */

require __DIR__ . '/vendor/autoload.php';

use Google\Cloud\Firestore\FirestoreClient;

$projectId = getenv('GOOGLE_PROJECT_ID') ?: null;
$credentials = getenv('GOOGLE_APPLICATION_CREDENTIALS') ?: null;
// CLI options: --date=YYYY-MM-DD --endpoint=URL --dry-run --attach-pdf --business=BUSINESS_ID --limit=N
$opts = getopt('', ['date:', 'endpoint:', 'dry-run', 'attach-pdf', 'business:', 'limit:']);
$requestedDate = $opts['date'] ?? null;
$endpoint = $opts['endpoint'] ?? getenv('DAILY_REPORT_ENDPOINT') ?: (getenv('SITE_BASE_URL') ? rtrim(getenv('SITE_BASE_URL'), '/') . '/emailtemplate/send_daily_sales_report.php' : (isset($argv[1]) ? $argv[1] : null));
$apiKey = getenv('DAILY_REPORT_API_KEY') ?: null;
$attachPdf = isset($opts['attach-pdf']) || getenv('DAILY_REPORT_ATTACH_PDF') === '1';
$dryRun = isset($opts['dry-run']);
$filterBusiness = $opts['business'] ?? null;
$docLimit = isset($opts['limit']) ? intval($opts['limit']) : (getenv('DAILY_REPORT_SCAN_LIMIT') ? intval(getenv('DAILY_REPORT_SCAN_LIMIT')) : 10000);
$postMaxAttempts = intval(getenv('DAILY_REPORT_POST_MAX_RETRIES') ?: 3);
$postTimeout = intval(getenv('DAILY_REPORT_POST_TIMEOUT') ?: 30);
$allowHttp = getenv('ALLOW_HTTP') === '1';

$logDir = __DIR__ . '/logs';
if (!is_dir($logDir)) mkdir($logDir, 0755, true);
$logFile = $logDir . '/generate_and_send.log';

function logLine($msg) {
    global $logFile;
    $line = '[' . date(DATE_ATOM) . '] ' . $msg . PHP_EOL;
    file_put_contents($logFile, $line, FILE_APPEND | LOCK_EX);
    echo $line;
}

// Validate configuration
if (empty($projectId) || empty($credentials)) {
    logLine('Missing required Firestore env vars (GOOGLE_PROJECT_ID, GOOGLE_APPLICATION_CREDENTIALS)');
    exit(1);
}

if (empty($endpoint) && !$dryRun) {
    logLine('No send endpoint configured. Set DAILY_REPORT_ENDPOINT or pass --endpoint. For local testing use --dry-run.');
    exit(1);
}

if (!empty($endpoint) && stripos($endpoint, 'http://') === 0 && !$allowHttp) {
    logLine("WARNING: Endpoint uses insecure http://. Set ALLOW_HTTP=1 to permit or use HTTPS.");
}

if (empty($apiKey) && !$dryRun) {
    logLine('Missing DAILY_REPORT_API_KEY env var (required to call the send endpoint)');
    exit(1);
}

// Helper: post with retries
function httpPostWithRetries($url, $payload, $apiKey, $maxAttempts = 3, $timeoutSeconds = 30) {
    $attempt = 0;
    $delay = 1;
    while ($attempt < $maxAttempts) {
        $attempt++;
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_HTTPHEADER, [
            'Content-Type: application/json',
            'X-API-KEY: ' . $apiKey
        ]);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
        curl_setopt($ch, CURLOPT_TIMEOUT, $timeoutSeconds);

        $resp = curl_exec($ch);
        $err = curl_error($ch);
        $status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($err) {
            logLine("HTTP POST attempt {$attempt}/{$maxAttempts} failed: {$err}");
            if ($attempt < $maxAttempts) {
                sleep($delay);
                $delay *= 2;
                continue;
            }
            return [false, 0, null, $err];
        }

        // Retry on server errors
        if ($status >= 500 && $attempt < $maxAttempts) {
            logLine("HTTP POST attempt {$attempt}/{$maxAttempts} returned status {$status}, retrying...");
            sleep($delay);
            $delay *= 2;
            continue;
        }

        // Successful or client error (don't retry for 4xx)
        return [true, $status, $resp, null];
    }

    return [false, 0, null, 'MaxAttemptsExceeded'];
}

function logLine($msg) {
    global $logFile;
    $line = '[' . date(DATE_ATOM) . '] ' . $msg . PHP_EOL;
    file_put_contents($logFile, $line, FILE_APPEND | LOCK_EX);
    echo $line;
}

if (empty($projectId) || empty($credentials) || empty($endpoint) || empty($apiKey)) {
    logLine('Missing required environment variables (GOOGLE_PROJECT_ID, GOOGLE_APPLICATION_CREDENTIALS, DAILY_REPORT_ENDPOINT, DAILY_REPORT_API_KEY)');
    exit(1);
}

// Setup Firestore client
try {
    $db = new FirestoreClient([
        'projectId' => $projectId,
        'keyFilePath' => $credentials,
    ]);
} catch (Exception $e) {
    logLine('Failed to initialize Firestore client: ' . $e->getMessage());
    exit(1);
}

// Define target day (yesterday)
$tz = new DateTimeZone('UTC');
$today = new DateTime('now', $tz);
$yesterday = (clone $today)->modify('-1 day');
$start = DateTime::createFromFormat('Y-m-d H:i:s', $yesterday->format('Y-m-d') . ' 00:00:00', $tz);
$end = DateTime::createFromFormat('Y-m-d H:i:s', $yesterday->format('Y-m-d') . ' 23:59:59', $tz);

logLine("Generating daily sales reports for date: " . $yesterday->format('Y-m-d'));

try {
    // Fetch recent transactions (we'll filter by date locally for resilience)
    $query = $db->collection('payment_transactions')->orderBy('createdAt', 'DESC');
    if ($docLimit > 0) {
        $query = $query->limit($docLimit);
    }
    $documents = $query->documents();

    $byBusiness = [];
    foreach ($documents as $doc) {
        if (!$doc->exists()) continue;
        $data = $doc->data();

        // Normalize createdAt
        $created = null;
        if (isset($data['createdAt'])) {
            $ca = $data['createdAt'];
            // If it's a Firestore Timestamp object (Google\Cloud\Core\Timestamp)
            if (is_object($ca) && method_exists($ca, 'get')) {
                // get returns DateTime
                $dt = $ca->get();
                $created = DateTime::createFromFormat(DateTime::ATOM, $dt->format(DATE_ATOM), $tz);
            } else if (is_string($ca)) {
                $created = DateTime::createFromFormat(DateTime::ISO8601, $ca, $tz);
                if (!$created) $created = DateTime::createFromFormat('Y-m-d\TH:i:sP', $ca, $tz);
                if (!$created) $created = DateTime::createFromFormat('Y-m-d H:i:s', $ca, $tz);
            } else if (is_numeric($ca)) {
                $created = (new DateTime('@' . intval($ca)))->setTimezone($tz);
            }
        }

        if ($created === null) continue; // skip if no parsable time

        // Skip if not in yesterday range
        if ($created < $start || $created > $end) continue;

        $businessId = isset($data['businessId']) ? (string)$data['businessId'] : '';
        if ($businessId === '') continue;

        if ($filterBusiness !== null && $filterBusiness !== '' && $filterBusiness !== $businessId) continue;

        if (!isset($byBusiness[$businessId])) $byBusiness[$businessId] = [];
        $byBusiness[$businessId][] = array_merge($data, ['id' => $doc->id()]);
    }

    logLine('Found ' . count($byBusiness) . ' businesses with transactions for the date.');

    $summary = [];
    foreach ($byBusiness as $businessId => $transactions) {
        // Fetch business doc to get recipient email
        $bdoc = $db->collection('businesses')->document($businessId)->snapshot();
        $recipient = '';
        $businessName = $businessId;
        if ($bdoc->exists()) {
            $bdata = $bdoc->data();
            $recipient = isset($bdata['email']) ? $bdata['email'] : '';
            $businessName = isset($bdata['name']) ? $bdata['name'] : $businessName;
        }

        if (empty($recipient)) {
            logLine("Skipping business $businessId - no recipient email");
            continue;
        }

        // Build transactions payload (simple mapping)
        $txRows = [];
        $totalAmount = 0.0;
        foreach ($transactions as $t) {
            $amount = 0.0;
            if (isset($t['amount'])) {
                $amount = floatval($t['amount']);
            }
            $totalAmount += $amount;
            $txRows[] = [
                'orderId' => $t['id'] ?? ($t['transactionId'] ?? ''),
                'customer' => $t['customer'] ?? $t['email'] ?? 'Customer',
                'itemsCount' => isset($t['items']) ? count($t['items']) : ($t['itemsCount'] ?? 1),
                'paymentMethod' => $t['paymentMethod'] ?? $t['method'] ?? ($t['paymentGateway'] ?? 'Unknown'),
                'amount' => $amount,
                'createdAt' => isset($t['createdAt']) && is_string($t['createdAt']) ? $t['createdAt'] : (isset($t['createdAt']) && is_object($t['createdAt']) ? $t['createdAt']->get()->format(DATE_ATOM) : ''),
            ];
        }

        $payload = [
            'recipient' => $recipient,
            'businessName' => $businessName,
            'reportDate' => $yesterday->format('Y-m-d'),
            'currency' => $bdoc->exists() && isset($bdoc->data()['currency']) ? $bdoc->data()['currency'] : '₦',
            'transactions' => $txRows,
            'totals' => [
                'totalAmount' => $totalAmount,
                'totalTransactions' => count($txRows)
            ],
            'attachPdf' => $attachPdf
        ];

        // Dry-run: write payload to log for inspection
        if ($dryRun) {
            $outFile = $logDir . "/payload_{$businessId}_{$yesterday->format('Ymd')}.json";
            file_put_contents($outFile, json_encode($payload, JSON_PRETTY_PRINT));
            logLine("Dry-run: payload written to {$outFile}");
            $summary[] = ['businessId' => $businessId, 'status' => 'dry_run', 'path' => $outFile];
            continue;
        }

        // Post to send endpoint with retries
        list($ok, $status, $resp, $error) = httpPostWithRetries($endpoint, $payload, $apiKey, $postMaxAttempts, $postTimeout);

        if ($error) {
            logLine("Failed to send report for business {$businessId} ({$businessName}) to {$recipient}: {$error}");
            $summary[] = ['businessId' => $businessId, 'status' => 'curl_error', 'error' => $error];
            continue;
        }

        if ($status !== 200) {
            logLine("Send endpoint returned status {$status} for business {$businessId}: {$resp}");
            $summary[] = ['businessId' => $businessId, 'status' => 'http_' . $status, 'response' => $resp];
            continue;
        }

        $respData = json_decode($resp, true);
        if (!is_array($respData) || !($respData['ok'] ?? false)) {
            logLine("Send failed for business {$businessId}: {$resp}");
            $summary[] = ['businessId' => $businessId, 'status' => 'send_failed', 'response' => $resp];
            continue;
        }

        logLine("Report sent for business {$businessId} ({$businessName}) to {$recipient}");
        $summary[] = ['businessId' => $businessId, 'status' => 'sent'];
    }

    logLine('Finished processing reports. Summary: ' . json_encode($summary));
    exit(0);
} catch (Exception $e) {
    logLine('Exception during report generation: ' . $e->getMessage());
    exit(1);
}
