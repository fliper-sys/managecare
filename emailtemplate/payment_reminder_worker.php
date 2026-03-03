<?php
// Payment reminder worker: fetch due payments and send upcoming payment reminders to Real Estate admins.
// Usage: set BUSINESS_API_URL and BUSINESS_API_KEY environment variables, then run via cron daily.

$apiUrl = getenv('BUSINESS_API_URL');
$apiKey = getenv('BUSINESS_API_KEY');
$templateFile = __DIR__ . '/manage-care-email (1).html';

function fetch_due_payments($apiUrl, $apiKey) {
    $url = rtrim($apiUrl, '/') . '/due_payments.php';
    if ($apiKey) $url .= '?api_key=' . urlencode($apiKey);
    $ctx = stream_context_create(['http' => ['timeout' => 20]]);
    $json = @file_get_contents($url, false, $ctx);
    if ($json === false) return null;
    $data = json_decode($json, true);
    return is_array($data) ? $data : null;
}

require_once __DIR__ . '/mail.php';
require_once __DIR__ . '/template_renderer.php';

$payload = fetch_due_payments($apiUrl, $apiKey);
if (!is_array($payload)) {
    echo "No due payments data available. Ensure BUSINESS_API_URL and endpoint are configured.\n";
    exit(0);
}

// Expected payload: [{businessId, businessName, businessType, admins: [emails], duePayments: [{invoice, dueDate, amount}]}]
foreach ($payload as $biz) {
    $btype = strtolower($biz['businessType'] ?? '');
    // We target real estate admins for upcoming payment alerts (can be extended)
    if ($btype !== 'realestate') continue;

    $admins = $biz['admins'] ?? [];
    if (empty($admins)) continue;

    // Extract payment-reminder template
    $dom = new DOMDocument();
    libxml_use_internal_errors(true);
    $dom->loadHTML('<?xml encoding="utf-8" ?>' . file_get_contents($templateFile));
    $xpath = new DOMXPath($dom);
    $nodeList = $xpath->query("//*[@id='payment-reminder-email']");
    if ($nodeList->length === 0) continue;
    $node = $nodeList->item(0);
    $body = '';
    foreach ($node->childNodes as $c) $body .= $dom->saveHTML($c);

    // Prepare data
    $data = [
        'businessName' => $biz['businessName'] ?? ($biz['businessId'] ?? 'Business'),
        'payments' => [],
    ];
    foreach ($biz['duePayments'] ?? [] as $p) {
        $data['payments'][] = [
            'invoice_id' => $p['invoice'] ?? '',
            'due_date' => $p['dueDate'] ?? '',
            'amount' => isset($p['amount']) ? (string)$p['amount'] : '',
        ];
    }

    $rendered = tpl_render($body, $data);
    $subject = "Payment Due: " . ($data['businessName'] ?? 'Business');

    foreach ($admins as $email) {
        $ok = send_mail($email, $subject, $rendered);
        echo date('c') . " - Sent payment reminder to {$email}: " . ($ok ? 'OK' : 'FAILED') . "\n";
    }
}

?>
