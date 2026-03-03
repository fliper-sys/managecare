<?php
/**
 * Receipt Email Listener & Processor
 * Endpoint: POST receipt_email_listener.php
 * 
 * Handles receipt email requests from the Flutter app with:
 * - Receipt generation and formatting
 * - Email sending with customization
 * - PDF attachment generation (if enabled)
 * - Delivery tracking and logging
 * - Subscription/Plan restrictions
 * 
 * Required POST fields:
 *  - api_key: Authentication
 *  - recipient: Customer email
 *  - businessName: Business sending receipt
 *  - receiptText: Plain text receipt content
 *  - orderId: (optional) Order/Sale ID
 *  - businessId: (optional) Business ID for tracking
 *  - isPro: (optional) 'true' if Pro user (default: false)
 * 
 * Optional POST fields:
 *  - receiptType: 'simple', 'detailed', 'invoice' (default: 'detailed')
 *  - includeItemization: 'true'/'false' (default: true)
 *  - logoUrl: URL to business logo
 *  - businessEmail: Business email for reply-to
 *  - businessPhone: Business phone
 *  - customerName: Customer name for personalization
 *  - generatePDF: 'true' to generate PDF attachment (Pro feature)
 *  - theme: 'light', 'dark', 'professional', 'casual' (default: 'professional')
 *  - sendCopy: 'true' to also send copy to business email
 */

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Requested-With');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit(json_encode(['success' => true]));
}

// ============================================================================
// CONFIGURATION
// ============================================================================

require_once __DIR__ . '/_config.php';
$api_key = getenv('EMAIL_API_KEY') ?: $API_KEY;
$max_size_mb = 25;
$pdf_enabled = true;
$logging_enabled = true;
$log_file = __DIR__ . '/logs/receipt_emails.log';
$receipt_archive_dir = __DIR__ . '/receipt_archives/';

// Create necessary directories
if (!file_exists($log_file)) {
    @mkdir(dirname($log_file), 0777, true);
}
if (!file_exists($receipt_archive_dir)) {
    @mkdir($receipt_archive_dir, 0777, true);
}
// Ensure logs directory exists and log the incoming request for debugging
$logDir = __DIR__ . '/logs';
if (!is_dir($logDir)) @mkdir($logDir, 0755, true);
file_put_contents($logDir . '/receipt_requests.log', date('c') . " REQUEST: " . json_encode(['post' => $_POST, 'files' => array_keys($_FILES)]) . PHP_EOL, FILE_APPEND);

// ============================================================================
// AUTHENTICATION
// ============================================================================

$auth_key = isset($_POST['api_key']) ? trim($_POST['api_key']) : null;
if (!$auth_key || $auth_key !== $api_key) {
    http_response_code(401);
    exit(json_encode(['success' => false, 'error' => 'Unauthorized: Invalid API key']));
}

// ============================================================================
// REQUEST VALIDATION
// ============================================================================

$required_fields = ['recipient', 'businessName', 'receiptText'];
foreach ($required_fields as $field) {
    if (empty($_POST[$field])) {
        http_response_code(400);
        exit(json_encode(['success' => false, 'error' => "Missing required field: $field"]));
    }
}

// Validate email
$recipient = filter_var($_POST['recipient'], FILTER_VALIDATE_EMAIL);
if (!$recipient) {
    http_response_code(400);
    exit(json_encode(['success' => false, 'error' => 'Invalid recipient email']));
}

// ============================================================================
// EXTRACT REQUEST DATA
// ============================================================================

$businessName = htmlspecialchars(trim($_POST['businessName']), ENT_QUOTES, 'UTF-8');
$receiptText = trim($_POST['receiptText']);
$orderId = isset($_POST['orderId']) ? htmlspecialchars(trim($_POST['orderId']), ENT_QUOTES, 'UTF-8') : null;
$businessId = isset($_POST['businessId']) ? htmlspecialchars(trim($_POST['businessId']), ENT_QUOTES, 'UTF-8') : null;
$isPro = (isset($_POST['isPro']) && strtolower($_POST['isPro']) === 'true');

$receiptType = isset($_POST['receiptType']) ? strtolower(trim($_POST['receiptType'])) : 'detailed';
$includeItemization = !(isset($_POST['includeItemization']) && strtolower($_POST['includeItemization']) === 'false');
$logoUrl = isset($_POST['logoUrl']) ? filter_var($_POST['logoUrl'], FILTER_VALIDATE_URL) : null;
$businessEmail = isset($_POST['businessEmail']) ? filter_var($_POST['businessEmail'], FILTER_VALIDATE_EMAIL) : null;
$businessPhone = isset($_POST['businessPhone']) ? htmlspecialchars(trim($_POST['businessPhone']), ENT_QUOTES, 'UTF-8') : null;
$customerName = isset($_POST['customerName']) ? htmlspecialchars(trim($_POST['customerName']), ENT_QUOTES, 'UTF-8') : 'Valued Customer';
$generatePDF = (isset($_POST['generatePDF']) && strtolower($_POST['generatePDF']) === 'true');
$theme = isset($_POST['theme']) ? strtolower(trim($_POST['theme'])) : 'professional';
$sendCopy = (isset($_POST['sendCopy']) && strtolower($_POST['sendCopy']) === 'true');

// ============================================================================
// FEATURE GATING
// ============================================================================

// PDF generation is a Pro feature
if ($generatePDF && !$isPro) {
    http_response_code(403);
    log_receipt_event('PDF_GENERATION_DENIED', [
        'recipient' => $recipient,
        'businessId' => $businessId,
        'reason' => 'Pro plan required'
    ]);
    exit(json_encode([
        'success' => false,
        'error' => 'PDF receipt generation is a Pro feature',
        'upgrade_required' => true
    ]));
}

// ============================================================================
// GENERATE EMAIL CONTENT
// ============================================================================

$htmlContent = generate_receipt_html(
    $receiptText,
    $businessName,
    $logoUrl,
    $businessEmail,
    $businessPhone,
    $customerName,
    $orderId,
    $theme,
    $receiptType
);

// Inline CSS to ensure styles are rendered in email clients
require_once __DIR__ . '/inline_styles.php';
// Prepare global CSS (the function builds the head style automatically)
$globalCss = '';
$dom = new DOMDocument();
libxml_use_internal_errors(true);
$dom->loadHTML('<?xml encoding="utf-8" ?>' . $htmlContent);
$styleTags = $dom->getElementsByTagName('style');
for ($i = 0; $i < $styleTags->length; $i++) {
  $globalCss .= "\n" . $styleTags->item($i)->nodeValue;
}
$htmlContent = inline_css($htmlContent, $globalCss);

$subject = "Receipt from {$businessName}" . ($orderId ? " - Order #{$orderId}" : "");

// Sanitize subject for email headers
$subject = preg_replace('/\s+/', ' ', trim($subject));

// ============================================================================
// PREPARE ATTACHMENTS
// ============================================================================

$attachments = [];

if ($generatePDF && $isPro) {
    // Generate PDF if requested (requires mPDF or similar library)
    $pdf_path = generate_receipt_pdf($receiptText, $businessName, $orderId);
    if ($pdf_path && file_exists($pdf_path)) {
        $attachments[] = $pdf_path;
    }
}

// ============================================================================
// SEND EMAIL
// ============================================================================

require_once __DIR__ . '/mail.php';

$ok = send_mail($recipient, $subject, $htmlContent, $attachments);

if (!$ok) {
    http_response_code(500);
    // Write a detailed debug log for failures
    file_put_contents($logDir . '/receipt_emails_debug.log', date('c') . " SEND_FAILED recipient:" . $recipient . " subject:" . $subject . " post:" . json_encode($_POST) . " files:" . json_encode(array_keys($_FILES)) . PHP_EOL, FILE_APPEND);
    log_receipt_event('SEND_FAILED', [
        'recipient' => $recipient,
        'businessId' => $businessId,
        'orderId' => $orderId,
    ]);
    // Include last PHPMailer error in response if available
    $errFile = __DIR__ . '/logs/email_errors.log';
    $debugErr = null;
    if (file_exists($errFile)) {
        $lines = file($errFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if ($lines !== false && count($lines) > 0) {
            $debugErr = $lines[count($lines)-1];
        }
    }
    // Include the last few lines of the SMTP debug log if present
    $smtpDebugFile = __DIR__ . '/logs/phpsmtp_debug.log';
    $smtpDebug = null;
    if (file_exists($smtpDebugFile)) {
        $dlines = file($smtpDebugFile, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if ($dlines !== false && count($dlines) > 0) {
            $smtpDebug = implode("\n", array_slice($dlines, -20));
        }
    }
    exit(json_encode(['success' => false, 'error' => 'Failed to send receipt email', 'debug_error' => $debugErr, 'smtp_debug' => $smtpDebug]));
}

// Send copy to business if requested
if ($sendCopy && $businessEmail) {
    $copy_subject = "[Copy] {$subject}";
    $copy_html = str_replace(
        "Dear {$customerName}",
        "This is a copy of the receipt sent to {$recipient}",
        $htmlContent
    );
    send_mail($businessEmail, $copy_subject, $copy_html, $attachments);
}

// ============================================================================
// ARCHIVE AND LOGGING
// ============================================================================

$receipt_id = uniqid('rcpt_');
$archive_data = [
    'receipt_id' => $receipt_id,
    'timestamp' => date('Y-m-d H:i:s'),
    'recipient' => $recipient,
    'business_name' => $businessName,
    'business_id' => $businessId,
    'order_id' => $orderId,
    'is_pro' => $isPro,
    'generated_pdf' => $generatePDF && count($attachments) > 0,
    'theme' => $theme,
    'receipt_type' => $receiptType
];

// Save archive
save_receipt_archive($receipt_id, $receiptText, $archive_data);
log_receipt_event('SENT_SUCCESS', array_merge($archive_data, ['recipient' => $recipient]));

// ============================================================================
// RESPONSE
// ============================================================================

http_response_code(200);
echo json_encode([
    'success' => true,
    'message' => 'Receipt email sent successfully',
    'receipt_id' => $receipt_id,
    'sent_to' => $recipient,
    'timestamp' => date('Y-m-d H:i:s'),
    'features' => [
        'pdf_attached' => $generatePDF && count($attachments) > 0,
        'business_copy_sent' => $sendCopy && $businessEmail ? true : false
    ]
]);

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Generate HTML email content for receipt
 */
function generate_receipt_html($receiptText, $businessName, $logoUrl = null, $businessEmail = null, $businessPhone = null, $customerName = 'Valued Customer', $orderId = null, $theme = 'professional', $receiptType = 'detailed') {
    // Determine theme colors
    $colors = get_theme_colors($theme);
    
    $logoHtml = '';
    if ($logoUrl) {
        $logoHtml = <<<HTML
        <div style="text-align: center; margin-bottom: 20px;">
            <img src="{$logoUrl}" alt="{$businessName}" style="max-width: 150px; height: auto;" />
        </div>
        HTML;
    }
    
    $contactHtml = '';
    if ($businessEmail || $businessPhone) {
        $contactHtml = '<div style="margin-top: 15px; font-size: 12px; color: #666;">';
        if ($businessEmail) {
            $contactHtml .= "Email: <a href=\"mailto:{$businessEmail}\">{$businessEmail}</a><br>";
        }
        if ($businessPhone) {
            $contactHtml .= "Phone: {$businessPhone}<br>";
        }
        $contactHtml .= '</div>';
    }
    
    $html = <<<HTML
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; background: #f9f9f9; }
            .header { background: {$colors['primary']}; color: white; padding: 20px; border-radius: 5px 5px 0 0; text-align: center; }
            .content { background: white; padding: 20px; border: 1px solid #ddd; border-radius: 0 0 5px 5px; }
            .receipt-text { background: #f5f5f5; padding: 15px; font-family: monospace; font-size: 12px; white-space: pre-wrap; overflow-x: auto; border-left: 3px solid {$colors['primary']}; }
            .footer { margin-top: 20px; font-size: 12px; color: #666; text-align: center; }
            .receipt-id { margin-top: 10px; font-size: 11px; color: #999; }
            a { color: {$colors['accent']}; text-decoration: none; }
            a:hover { text-decoration: underline; }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                {$logoHtml}
                <h1 style="margin: 0;">{$businessName}</h1>
                <p style="margin: 5px 0 0 0;">Receipt Confirmation</p>
            </div>
            <div class="content">
                <p>Dear {$customerName},</p>
                <p>Thank you for your purchase! Here is your receipt:</p>
                
                <div class="receipt-text">{$receiptText}</div>
                
                {$contactHtml}
                
                <div style="margin-top: 20px; padding: 10px; background: {$colors['light']}; border-radius: 3px; font-size: 12px;">
                    <strong>Receipt Details:</strong><br>
                    Issued: " . date('Y-m-d H:i:s') . "<br>
                    Receipt ID: " . uniqid() . ($orderId ? "<br>Order ID: {$orderId}" : "") . "
                </div>
                
                <div class="footer">
                    <p>If you have any questions about this receipt, please contact us.</p>
                    <p style="margin-top: 15px; color: #999; font-size: 11px;">This is an automated email. Please do not reply directly.</p>
                </div>
            </div>
        </div>
    </body>
    </html>
    HTML;
    
    return $html;
}

/**
 * Get theme colors based on theme name
 */
function get_theme_colors($theme) {
    $themes = [
        'professional' => [
            'primary' => '#1e3a8a',
            'accent' => '#0066cc',
            'light' => '#f0f4ff'
        ],
        'light' => [
            'primary' => '#6366f1',
            'accent' => '#818cf8',
            'light' => '#f0f1ff'
        ],
        'dark' => [
            'primary' => '#1f2937',
            'accent' => '#374151',
            'light' => '#f3f4f6'
        ],
        'casual' => [
            'primary' => '#f97316',
            'accent' => '#fb923c',
            'light' => '#fff7ed'
        ]
    ];
    
    return $themes[$theme] ?? $themes['professional'];
}

/**
 * Generate PDF receipt (requires mPDF or similar)
 * This is a placeholder - implement with actual PDF library
 */
function generate_receipt_pdf($receiptText, $businessName, $orderId) {
    // Check if mPDF is available
    if (!class_exists('Mpdf\Mpdf')) {
        return null; // mPDF not installed
    }
    
    try {
        $pdf = new \Mpdf\Mpdf([
            'orientation' => 'P',
            'format' => 'A4',
            'tempDir' => sys_get_temp_dir()
        ]);
        
        $html = "
            <h1>" . htmlspecialchars($businessName, ENT_QUOTES, 'UTF-8') . "</h1>
            <pre>" . htmlspecialchars($receiptText, ENT_QUOTES, 'UTF-8') . "</pre>
            <p style='font-size: 10px; color: #999;'>Generated: " . date('Y-m-d H:i:s') . "</p>
        ";
        
        $pdf->writeHTML($html);
        
        $filename = 'receipt_' . ($orderId ? $orderId : uniqid()) . '.pdf';
        $filepath = sys_get_temp_dir() . '/' . $filename;
        $pdf->output($filepath, 'F');
        
        return file_exists($filepath) ? $filepath : null;
    } catch (Exception $e) {
        error_log('PDF generation error: ' . $e->getMessage());
        return null;
    }
}

/**
 * Save receipt to archive
 */
function save_receipt_archive($receipt_id, $receiptText, $metadata) {
    global $receipt_archive_dir;
    
    $archive_json = json_encode(array_merge(['receipt_text' => $receiptText], $metadata), JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    $archive_file = $receipt_archive_dir . $receipt_id . '.json';
    
    file_put_contents($archive_file, $archive_json);
    chmod($archive_file, 0644);
}

/**
 * Log receipt event
 */
function log_receipt_event($event, $data) {
    global $log_file, $logging_enabled;
    
    if (!$logging_enabled) return;
    
    $timestamp = date('Y-m-d H:i:s');
    $log_entry = "[$timestamp] EVENT: {$event} | DATA: " . json_encode($data) . "\n";
    
    @file_put_contents($log_file, $log_entry, FILE_APPEND);
}

?>
