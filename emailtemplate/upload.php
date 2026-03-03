<?php
// CORS Headers - must be first
$origin = isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : '*';
header("Access-Control-Allow-Origin: $origin");
header('Vary: Origin');
// Allow methods and headers commonly used by clients (including Authorization and api_key)
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Requested-With, Authorization, Api-Key, api_key, Accept, Origin, X-Client-Debug');
// Allow credentials if clients send cookies or auth headers
header('Access-Control-Allow-Credentials: true');
// Cache preflight for 1 day
header('Access-Control-Max-Age: 86400');
// Marker header to verify this PHP file executed
header('X-CORS-PATCH: applied');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    // Ensure preflight response includes all CORS headers above and return 200
    http_response_code(200);
    exit();
}

// Set content type for actual requests
header('Content-Type: application/json');

require_once __DIR__ . '/_config.php';
$api_key = getenv('EMAIL_API_KEY') ?: $API_KEY;
// Allow api_key via POST field or Authorization header (Bearer)
$providedKey = $_POST['api_key'] ?? null;
if (empty($providedKey)) {
    $hdr = isset($_SERVER['HTTP_AUTHORIZATION']) ? trim($_SERVER['HTTP_AUTHORIZATION']) : '';
    if (stripos($hdr, 'Bearer ') === 0) {
        $providedKey = substr($hdr, 7);
    }
}

if (!$providedKey || $providedKey !== $api_key) {
    http_response_code(401);
    echo json_encode(["error" => "Unauthorized"]);
    exit;
}

// --- File Size Limit (e.g., 20MB) ---
$max_file_size = 20 * 1024 * 1024; // 20MB

$target_dir = __DIR__ . "/uploads/";
if (!file_exists($target_dir)) {
    mkdir($target_dir, 0755, true);
}

// Expanded allowed MIME types to include common office and spreadsheet formats
$allowed_types = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'application/pdf',
    'text/csv',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
];

// Per-type size limits (bytes). Defaults to 20MB if not listed below.
$type_limits = [
    'image/jpeg' => 20 * 1024 * 1024,
    'image/png' => 20 * 1024 * 1024,
    'image/gif' => 10 * 1024 * 1024,
    'application/pdf' => 20 * 1024 * 1024,
    'text/csv' => 5 * 1024 * 1024,
    'application/vnd.ms-excel' => 10 * 1024 * 1024,
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' => 10 * 1024 * 1024,
    'application/msword' => 10 * 1024 * 1024,
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document' => 10 * 1024 * 1024,
];

$saved = [];

if (empty($_FILES)) {
    http_response_code(400);
    echo json_encode(["error" => "No files were uploaded"]);
    exit;
}

// Helper: save a single uploaded file entry and return URL or null
function save_uploaded_file($fileEntry, $target_dir, $allowed_types, $max_file_size) {
    // Determine if this is a single file or an array of files
    if (is_string($fileEntry['name'])) {
        $files = [$fileEntry];
    } else {
        $files = [];
        for ($i = 0; $i < count($fileEntry['name']); $i++) {
            $files[] = [
                'name' => $fileEntry['name'][$i],
                'type' => $fileEntry['type'][$i],
                'tmp_name' => $fileEntry['tmp_name'][$i],
                'error' => $fileEntry['error'][$i],
                'size' => $fileEntry['size'][$i],
            ];
        }
    }

    $results = [];
    foreach ($files as $f) {
        if ($f['error'] !== UPLOAD_ERR_OK) {
            $results[] = ['error' => 'Upload error code ' . $f['error']];
            continue;
        }
        if ($f['size'] > $max_file_size) {
            $results[] = ['error' => 'File too large. Max size is 20MB.'];
            continue;
        }

        // Use finfo to detect mime type reliably
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mime = finfo_file($finfo, $f['tmp_name']);
        finfo_close($finfo);
        if (!in_array($mime, $allowed_types)) {
            $results[] = ['error' => 'Invalid file type.'];
            continue;
        }

        // Apply per-type size limit when available
        $limit = $type_limits[$mime] ?? $max_file_size;
        if ($f['size'] > $limit) {
            $results[] = ['error' => 'File too large for type: max ' . round($limit / (1024 * 1024)) . 'MB'];
            continue;
        }

        $safeName = preg_replace('/[^A-Za-z0-9_\-.]/', '_', basename($f['name']));
        $filename = uniqid() . '_' . $safeName;
        $target_file = rtrim($target_dir, '/') . '/' . $filename;

        if (move_uploaded_file($f['tmp_name'], $target_file)) {
            @chmod($target_file, 0644);
            $url = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https://' : 'http://') . $_SERVER['HTTP_HOST'] . '/emailtemplate' . str_replace('\\\\', '/', str_replace(__DIR__, '', $target_file));
            $results[] = ['url' => $url, 'path' => $target_file];
        } else {
            $results[] = ['error' => 'Failed to move uploaded file.'];
        }
    }

    return $results;
}

// Process all file fields (support 'image', 'attachments', 'attachments[]', etc.)
foreach ($_FILES as $field => $fileEntry) {
    $res = save_uploaded_file($fileEntry, $target_dir, $allowed_types, $max_file_size);
    foreach ($res as $r) $saved[] = $r;
}

if (empty($saved)) {
    http_response_code(500);
    echo json_encode(["error" => "No files saved"]);
    exit;
}

// Build response: collect successful urls
$urls = array_values(array_filter(array_map(function($r){ return $r['url'] ?? null; }, $saved)));

// Helpful debug fields to confirm which origin and headers reached the server
$debugInfo = [
    'request_origin' => isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : null,
    'has_authorization_header' => isset($_SERVER['HTTP_AUTHORIZATION']),
    'received_api_key_field' => isset($_POST['api_key']),
];

if (count($urls) === 1) {
    echo json_encode(["url" => $urls[0], "urls" => $urls, "details" => $saved, "debug" => $debugInfo]);
} else {
    echo json_encode(["urls" => $urls, "details" => $saved, "debug" => $debugInfo]);
}
?>