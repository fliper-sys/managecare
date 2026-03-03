<?php
// Simple dunning trigger endpoint
// POST fields: api_key (required), force (optional)
// Writes a trigger file used by the app/server to know when to run dunning

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

echo json_encode(['success' => true, 'message' => 'Dunning trigger recorded', 'payload' => $payload]);

?>