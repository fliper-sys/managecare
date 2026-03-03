<?php
// Weekly Financial Report Worker
// This script expects an API endpoint (BUSINESS_API_URL) that returns financial summaries per business
// Configure environment variables: BUSINESS_API_URL, BUSINESS_API_KEY

$apiUrl = getenv('BUSINESS_API_URL');
$apiKey = getenv('BUSINESS_API_KEY');
$templateFile = __DIR__ . '/manage-care-email (1).html';

require_once __DIR__ . '/mail.php';
require_once __DIR__ . '/template_renderer.php';

function fetch_financial_reports($apiUrl, $apiKey) {
    $url = rtrim($apiUrl, '/') . '/weekly_financials.php';
    if ($apiKey) $url .= '?api_key=' . urlencode($apiKey);
    $ctx = stream_context_create(['http' => ['timeout' => 30]]);
    $json = @file_get_contents($url, false, $ctx);
    if ($json === false) return null;
    $data = json_decode($json, true);
    return is_array($data) ? $data : null;
}

$payload = fetch_financial_reports($apiUrl, $apiKey);
if (!is_array($payload)) {
    echo "No financial data available. Ensure BUSINESS_API_URL and endpoint are configured.\n";
    exit(0);
}

// Load template container
$dom = new DOMDocument();
libxml_use_internal_errors(true);
$htmlContent = file_get_contents($templateFile);
$dom->loadHTML('<?xml encoding="utf-8" ?>' . $htmlContent);
$xpath = new DOMXPath($dom);

$nodeList = $xpath->query("//*[@id='weekly-financial-report-email']");
if ($nodeList->length === 0) {
    echo "Template 'weekly-financial-report-email' not found in templates file.\n";
    exit(0);
}
$node = $nodeList->item(0);
$body = '';
foreach ($node->childNodes as $c) $body .= $dom->saveHTML($c);

foreach ($payload as $bizReport) {
    $admins = $bizReport['admins'] ?? [];
    if (empty($admins)) continue;

    $data = [
        'businessName' => $bizReport['businessName'] ?? 'Business',
        'periodStart' => $bizReport['periodStart'] ?? '',
        'periodEnd' => $bizReport['periodEnd'] ?? '',
        'income' => $bizReport['income'] ?? 0,
        'expenses' => $bizReport['expenses'] ?? 0,
        'profit' => $bizReport['profit'] ?? 0,
        'profitMargin' => $bizReport['profitMargin'] ?? 0,
        'stockValue' => $bizReport['stockValue'] ?? 0,
        'charts' => $bizReport['charts'] ?? [],
    ];

    $rendered = tpl_render($body, $data);
    $subject = "Weekly Financial Summary: " . ($data['businessName'] ?? 'Business');

    foreach ($admins as $email) {
        $ok = send_mail($email, $subject, $rendered);
        echo date('c') . " - Sent weekly financial report to {$email}: " . ($ok ? 'OK' : 'FAILED') . "\n";
    }
}

?>