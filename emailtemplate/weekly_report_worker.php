<?php
// Weekly report worker: fetch business reports and send weekly analytics email to Pro businesses' admins.
// Usage: set BUSINESS_API_URL and BUSINESS_API_KEY environment variables, then run via cron weekly.

$apiUrl = getenv('BUSINESS_API_URL');
$apiKey = getenv('BUSINESS_API_KEY');
$templateFile = __DIR__ . '/manage-care-email (1).html';

function fetch_reports($apiUrl, $apiKey) {
    $url = rtrim($apiUrl, '/') . '/weekly_reports.php';
    if ($apiKey) $url .= '?api_key=' . urlencode($apiKey);
    $ctx = stream_context_create(['http' => ['timeout' => 20]]);
    $json = @file_get_contents($url, false, $ctx);
    if ($json === false) return null;
    $data = json_decode($json, true);
    return is_array($data) ? $data : null;
}

require_once __DIR__ . '/mail.php';
require_once __DIR__ . '/template_renderer.php';

$payload = fetch_reports($apiUrl, $apiKey);
if (!is_array($payload)) {
    echo "No report data available. Ensure BUSINESS_API_URL and endpoint are configured.\n";
    exit(0);
}

// Expected payload: [{businessId, businessName, subscriptionTier, admins: [emails], report: { ... report fields ... }}]
foreach ($payload as $biz) {
    $tier = strtolower($biz['subscriptionTier'] ?? 'free');
    if (!in_array($tier, ['professional', 'enterprise'])) continue; // Pro-only

    $admins = $biz['admins'] ?? [];
    if (empty($admins)) continue;

    // Extract analytics template
    $dom = new DOMDocument();
    libxml_use_internal_errors(true);
    $dom->loadHTML('<?xml encoding="utf-8" ?>' . file_get_contents($templateFile));
    $xpath = new DOMXPath($dom);
    $nodeList = $xpath->query("//*[@id='analytics-email']");
    if ($nodeList->length === 0) continue;
    $node = $nodeList->item(0);
    $body = '';
    foreach ($node->childNodes as $c) $body .= $dom->saveHTML($c);

    // Prepare data for template
    $data = $biz['report'] ?? [];
    $data['businessName'] = $biz['businessName'] ?? ($biz['businessId'] ?? 'Business');

    $rendered = tpl_render($body, $data);
    $subject = "Weekly Report: " . ($data['businessName'] ?? 'Business');

    foreach ($admins as $email) {
        $ok = send_mail($email, $subject, $rendered);
        echo date('c') . " - Sent weekly report to {$email}: " . ($ok ? 'OK' : 'FAILED') . "\n";
    }
}

?>
