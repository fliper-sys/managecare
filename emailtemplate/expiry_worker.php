<?php
// Expiry worker: fetch expiring items from an app API or read a JSON file and send expiry emails.
// Usage (cron):
// - Export BUSINESS_API_URL and BUSINESS_API_KEY as environment variables, where BUSINESS_API_URL is the base URL of your app's API that returns expiring items.
// - Or run: php expiry_worker.php /path/to/expiring.json

// Load configuration from env
$apiUrl = getenv('BUSINESS_API_URL');
$apiKey = getenv('BUSINESS_API_KEY');
$templateFile = __DIR__ . '/manage-care-email (1).html';

function fetch_data_from_api($apiUrl, $apiKey) {
    $url = rtrim($apiUrl, '/') . '/expiring_items.php';
    if ($apiKey) $url .= '?api_key=' . urlencode($apiKey);
    $ctx = stream_context_create(['http' => ['timeout' => 15]]);
    $json = @file_get_contents($url, false, $ctx);
    if ($json === false) return null;
    $data = json_decode($json, true);
    return is_array($data) ? $data : null;
}

require_once __DIR__ . '/mail.php';
require_once __DIR__ . '/template_renderer.php';

$inputFile = $argv[1] ?? null;
$payload = null;
if ($inputFile && file_exists($inputFile)) {
    $payload = json_decode(file_get_contents($inputFile), true);
} elseif ($apiUrl) {
    $payload = fetch_data_from_api($apiUrl, $apiKey);
}

if (!is_array($payload)) {
    echo "No data to process. Provide BUSINESS_API_URL/BUSINESS_API_KEY or a JSON file\n";
    exit(0);
}

// Expected payload format: array of businesses: [{businessId, businessName, ownerEmail, items: [{name, expiryDate, daysLeft}]}]
foreach ($payload as $biz) {
    $owner = $biz['ownerEmail'] ?? null;
    $items = $biz['items'] ?? [];
    $businessName = $biz['businessName'] ?? ($biz['businessId'] ?? 'Business');
    if (!$owner || empty($items)) continue;

    // Load template HTML and extract the expiry template
    $dom = new DOMDocument();
    libxml_use_internal_errors(true);
    $dom->loadHTML('<?xml encoding="utf-8" ?>' . file_get_contents($templateFile));
    $xpath = new DOMXPath($dom);
    $nodeList = $xpath->query("//*[@id='expiry-email']");
    if ($nodeList->length === 0) continue;
    $node = $nodeList->item(0);
    $body = '';
    foreach ($node->childNodes as $c) $body .= $dom->saveHTML($c);

    // Prepare data for template
    $data = [
        'businessName' => $businessName,
        'items' => [],
    ];
    foreach ($items as $it) {
        $data['items'][] = [
            'name' => $it['name'] ?? '',
            'expiryDate' => $it['expiryDate'] ?? '',
            'daysLeft' => isset($it['daysLeft']) ? (string)$it['daysLeft'] : '',
        ];
    }

    $rendered = tpl_render($body, $data);
    $subject = "Expiry Alert: {$businessName}";
    $ok = send_mail($owner, $subject, $rendered);
    echo date('c') . " - Sent expiry email to {$owner}: " . ($ok ? 'OK' : 'FAILED') . "\n";
}

?>
