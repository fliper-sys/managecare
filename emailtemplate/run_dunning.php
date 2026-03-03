<?php
// run_dunning.php
// Simple server-side runner to trigger the dunning trigger file and optionally call a backend run URL.

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Content-Type: application/json');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit(json_encode(['success' => true]));
}

require_once __DIR__ . '/_config.php';
$api_key = getenv('EMAIL_API_KEY') ?: $API_KEY;
if (!isset($_REQUEST['api_key']) || $_REQUEST['api_key'] !== $api_key) {
    http_response_code(401);
    echo json_encode(['success' => false, 'error' => 'Unauthorized']);
    exit;
}

$force = isset($_REQUEST['force']) && $_REQUEST['force'] === 'true';
$triggerFile = __DIR__ . '/dunning_trigger.json';

$payload = [
    'triggered_at' => date('c'),
    'timestamp' => time(),
    'ip' => $_SERVER['REMOTE_ADDR'] ?? '',
    'force' => $force ? true : false,
];

file_put_contents($triggerFile, json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

// Optionally call a backend runner URL passed as run_url to directly invoke dunning logic on the server
if (isset($_REQUEST['run_url']) && filter_var($_REQUEST['run_url'], FILTER_VALIDATE_URL)) {
    $runUrl = $_REQUEST['run_url'];
    // Use curl to invoke
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $runUrl);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 15);
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    echo json_encode(['success' => true, 'message' => 'Trigger written and backend invoked', 'payload' => $payload, 'backend_code' => $httpCode, 'backend_response' => $response]);
    exit;
}

echo json_encode(['success' => true, 'message' => 'Trigger written', 'payload' => $payload]);

?>