<?php
// Simple email API that uses the existing mail.php send_mail function and templates
// Endpoint: POST email_api.php
// Required POST fields: api_key, template, recipient
// Optional: subject, data (JSON encoded associative array), attachments[] (files)

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

header('Content-Type: application/json');

require_once __DIR__ . '/_config.php';
$api_key = getenv('EMAIL_API_KEY') ?: $API_KEY;
if (!isset($_POST['api_key']) || $_POST['api_key'] !== $api_key) {
    http_response_code(401);
    echo json_encode(["error" => "Unauthorized"]);
    exit;
}

// Simple request logging to assist with debugging
$logDir = __DIR__ . '/logs';
if (!is_dir($logDir)) @mkdir($logDir, 0755, true);
file_put_contents($logDir . '/email_api_requests.log', date('c') . " REQUEST: " . json_encode(['post' => $_POST, 'files' => array_keys($_FILES)]) . PHP_EOL, FILE_APPEND);

// Required
$template = isset($_POST['template']) ? trim($_POST['template']) : null;
$recipient = isset($_POST['recipient']) ? trim($_POST['recipient']) : null;
$subject = isset($_POST['subject']) ? trim($_POST['subject']) : null;
$dataJson = isset($_POST['data']) ? $_POST['data'] : null; // expected JSON

if (empty($template) || empty($recipient)) {
    http_response_code(400);
    echo json_encode(["error" => "Missing template or recipient"]);
    exit;
}

$data = [];
$providedEmailHtml = null;
if (!empty($dataJson)) {
    $decoded = json_decode($dataJson, true);
    if (is_array($decoded)) {
        $data = $decoded;
    }
}

// Normalize item payloads: support itemsJson (stringified array) or items (JSON string)
if (!empty($data)) {
    // If client sent itemsJson, decode it into items[] for PHP templates
    if (isset($data['itemsJson']) && is_string($data['itemsJson'])) {
        $decodedItems = json_decode($data['itemsJson'], true);
        if (is_array($decodedItems)) {
            $data['items'] = $decodedItems;
        }
    }

    // If items is provided as JSON string, decode it as well
    if (isset($data['items']) && is_string($data['items'])) {
        $decodedItems = json_decode($data['items'], true);
        if (is_array($decodedItems)) {
            $data['items'] = $decodedItems;
        }
    }

    // If caller provided a pre-rendered HTML block (emailHtml), prefer that and skip template lookup
    if (isset($data['emailHtml']) && is_string($data['emailHtml']) && trim($data['emailHtml']) !== '') {
        $providedEmailHtml = $data['emailHtml'];
    }
}

$bodyHtml = '';
if ($providedEmailHtml !== null) {
    $bodyHtml = $providedEmailHtml;
} else {
    // Load templates from the master HTML file by extracting the named container
    $templateFile = __DIR__ . '/manage-care-email (1).html';
    if (!file_exists($templateFile)) {
        http_response_code(500);
        echo json_encode(["error" => "Templates file missing"]);
        exit;
    }

    // Use DOMDocument to extract the element with id '{$template}-email'
    libxml_use_internal_errors(true);
    $dom = new DOMDocument();
    $htmlContent = file_get_contents($templateFile);
    // Ensure proper encoding
    $dom->loadHTML('<?xml encoding="utf-8" ?>' . $htmlContent);
    $xpath = new DOMXPath($dom);
    $id = substr($template, -6) === '-email' ? $template : $template . '-email';
    $nodeList = $xpath->query("//*[@id='$id']");
    if ($nodeList->length === 0) {
        // Fallback: look for a PHP template file under templates/<template>.php
        $phpTemplateFile = __DIR__ . '/templates/' . $template . '.php';
        if (file_exists($phpTemplateFile)) {
            // Make $data available to the template as variables
            if (is_array($data)) extract($data, EXTR_SKIP);
            ob_start();
            include $phpTemplateFile;
            $bodyHtml = ob_get_clean();
        } else {
            http_response_code(404);
            echo json_encode(["error" => "Template not found: $template"]);
            exit;
        }
    } else {
        $node = $nodeList->item(0);

        // Helper to get inner HTML
        function innerHTML($node) {
            $doc = $node->ownerDocument;
            $html = '';
            foreach ($node->childNodes as $child) {
                $html .= $doc->saveHTML($child);
            }
            return $html;
        }

        $bodyHtml = innerHTML($node);
    }

    // Use shared template renderer
    require_once __DIR__ . '/template_renderer.php';
    if (!empty($data) && is_array($data)) {
        $bodyHtml = tpl_render($bodyHtml, $data);
    }

    // Inline CSS from template head + any style blocks in the fragment
    require_once __DIR__ . '/inline_styles.php';
    $globalStyles = '';
    $globalStyleTags = $dom->getElementsByTagName('style');
    for ($i = 0; $i < $globalStyleTags->length; $i++) {
        $globalStyles .= "\n" . $globalStyleTags->item($i)->nodeValue;
    }
    $bodyHtml = inline_css($bodyHtml, $globalStyles);
}

// Default subject if none provided
if (empty($subject)) {
    $subject = 'Message from Manage Care';
}

// Handle attachments: store uploaded files into uploads/ and collect filesystem paths
$attachments = [];
$uploadDir = __DIR__ . '/uploads/';
if (!file_exists($uploadDir)) {
    mkdir($uploadDir, 0777, true);
}

// Support single file field 'attachment' or multiple 'attachments[]'
if (!empty($_FILES)) {
    foreach ($_FILES as $fieldName => $fileInfo) {
        // If a single file
        if (is_string($fileInfo['name'])) {
            if ($fileInfo['error'] === UPLOAD_ERR_OK) {
                $basename = uniqid() . '_' . basename($fileInfo['name']);
                $target = $uploadDir . $basename;
                if (move_uploaded_file($fileInfo['tmp_name'], $target)) {
                    $attachments[] = $target;
                }
            }
        } else if (is_array($fileInfo['name'])) {
            // multiple files
            for ($i = 0; $i < count($fileInfo['name']); $i++) {
                if ($fileInfo['error'][$i] === UPLOAD_ERR_OK) {
                    $basename = uniqid() . '_' . basename($fileInfo['name'][$i]);
                    $target = $uploadDir . $basename;
                    if (move_uploaded_file($fileInfo['tmp_name'][$i], $target)) {
                        $attachments[] = $target;
                    }
                }
            }
        }
    }
}

require_once __DIR__ . '/mail.php';

$ok = send_mail($recipient, $subject, $bodyHtml, $attachments);
if ($ok) {
    echo json_encode(["success" => true]);
} else {
    http_response_code(500);
    file_put_contents($logDir . '/email_api_debug.log', date('c') . " SEND_FAILED template:" . $template . " recipient:" . $recipient . " subject:" . $subject . " post:" . json_encode($_POST) . " files:" . json_encode(array_keys($_FILES)) . PHP_EOL, FILE_APPEND);
    // Try to include last PHPMailer error for debugging
    $errFile = __DIR__ . '/logs/email_errors.log';
    $debugErr = null;
    if (file_exists($errFile)) {
        $lines = file($errFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if ($lines !== false && count($lines) > 0) {
            $debugErr = $lines[count($lines)-1];
        }
    }
    $smtpDebugFile = __DIR__ . '/logs/phpsmtp_debug.log';
    $smtpDebug = null;
    if (file_exists($smtpDebugFile)) {
        $dlines = file($smtpDebugFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if ($dlines !== false && count($dlines) > 0) {
            $smtpDebug = implode("\n", array_slice($dlines, -20));
        }
    }
    echo json_encode(["error" => "Failed to send email", "debug_error" => $debugErr, "smtp_debug" => $smtpDebug]);
}

?>
