<?php
// profile-sync.php
// Simple endpoint to accept profile sync data and profile image uploads.
// - Accepts JSON body (application/json) and appends to a log file
// - Accepts multipart/form-data with a file field `image` and returns a public URL
// Security: requires X-API-Key header or `api_key` POST field to match the configured key

$API_KEY = '8f3b2c1e-4a7d-4e9a-8c2d-123456abcdef';
header('Content-Type: application/json; charset=utf-8');

function unauthorized($msg = 'Unauthorized') {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => $msg]);
    exit;
}

// Basic API key check: try header X-API-Key then POST field api_key
$apiKeyHeader = null;
if (function_exists('getallheaders')) {
    $hdrs = getallheaders();
    if (!empty($hdrs['X-API-Key'])) $apiKeyHeader = $hdrs['X-API-Key'];
    if (!empty($hdrs['x-api-key'])) $apiKeyHeader = $hdrs['x-api-key'];
}
$apiKeyPost = $_POST['api_key'] ?? null;
$key = $apiKeyHeader ?? $apiKeyPost;
if ($key !== $API_KEY) {
    unauthorized();
}

// Helper to build a public URL for the uploads folder
function base_url() {
    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    return $scheme . '://' . $host;
}

// Handle file upload (multipart/form-data) when `image` field is present
if (!empty($_FILES['image'])) {
    $file = $_FILES['image'];
    if ($file['error'] !== UPLOAD_ERR_OK) {
        http_response_code(400);
        echo json_encode(['success' => false, 'message' => 'File upload error', 'error' => $file['error']]);
        exit;
    }

    $uploadsDir = __DIR__ . '/../uploads/';
    if (!is_dir($uploadsDir)) {
        mkdir($uploadsDir, 0755, true);
    }

    $ext = pathinfo($file['name'], PATHINFO_EXTENSION);
    $filename = 'profile_' . time() . '_' . bin2hex(random_bytes(6)) . ($ext ? '.' . $ext : '');
    $destination = $uploadsDir . $filename;

    if (!move_uploaded_file($file['tmp_name'], $destination)) {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Failed to move uploaded file']);
        exit;
    }

    $publicUrl = rtrim(base_url(), '/') . '/uploads/' . $filename;
    echo json_encode(['success' => true, 'url' => $publicUrl, 'filename' => $filename]);
    exit;
}

// Otherwise accept JSON payload and append to a log file for inspection
$input = file_get_contents('php://input');
$payload = json_decode($input, true);
if ($payload === null) {
    // Not JSON or empty - return a helpful message
    echo json_encode(['success' => false, 'message' => 'No JSON payload provided and no file uploaded']);
    exit;
}

$logDir = __DIR__ . '/../data/';
if (!is_dir($logDir)) mkdir($logDir, 0755, true);
$logFile = $logDir . 'profile_sync.log';
$entry = [
    'timestamp' => date('c'),
    'payload' => $payload,
];
file_put_contents($logFile, json_encode($entry, JSON_UNESCAPED_SLASHES) . PHP_EOL, FILE_APPEND | LOCK_EX);

echo json_encode(['success' => true, 'message' => 'Profile payload received', 'logged_to' => 'data/profile_sync.log']);
exit;
