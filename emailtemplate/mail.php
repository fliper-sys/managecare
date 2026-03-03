<?php
  use PHPMailer\PHPMailer\PHPMailer;
  use PHPMailer\PHPMailer\Exception;
  require 'PHPMailer-master/src/Exception.php';
  require 'PHPMailer-master/src/PHPMailer.php';
  require 'PHPMailer-master/src/SMTP.php';

require_once __DIR__ . '/_config.php';

function send_mail($recipient, $subject, $message, $attachments = array())
{
    // Use configuration from env vars if present, otherwise fall back to _config.php
    $host = getenv('SMTP_HOST') ?: ($GLOBALS['SMTP_HOST'] ?? '');
    $user = getenv('SMTP_USER') ?: ($GLOBALS['SMTP_USER'] ?? '');
    $pass = getenv('SMTP_PASS') ?: ($GLOBALS['SMTP_PASS'] ?? '');
    $port = getenv('SMTP_PORT') ?: ($GLOBALS['SMTP_PORT'] ?? 587);
    $secure = getenv('SMTP_SECURE') ?: ($GLOBALS['SMTP_SECURE'] ?? 'tls');
    $from = getenv('SMTP_FROM') ?: ($GLOBALS['SMTP_FROM'] ?? $user);
    $fromName = getenv('SMTP_FROM_NAME') ?: ($GLOBALS['SMTP_FROM_NAME'] ?? 'Manage Care');

    $mail = new PHPMailer();
    $mail->isSMTP();

    // Debug mode via POST debug=1
    $debugMode = (isset($_POST['debug']) && $_POST['debug'] === '1');
    $mail->SMTPDebug = $debugMode ? 2 : 0;
    $mail->SMTPAuth  = true;

    // Apply config
    if (!empty($host)) $mail->Host = $host;
    if (!empty($user)) $mail->Username = $user;
    if (!empty($pass)) $mail->Password = $pass;
    $mail->Port = (int)$port;
    $mail->SMTPSecure = $secure;

    // Debug output to file
    $logDir = __DIR__ . '/logs';
    if (!is_dir($logDir)) @mkdir($logDir, 0755, true);
    if ($mail->SMTPDebug > 0) {
        $mail->Debugoutput = function($str, $level) use ($logDir) {
            file_put_contents($logDir . '/phpsmtp_debug.log', date('c') . " DEBUG[$level]: " . $str . PHP_EOL, FILE_APPEND);
        };
    }

    // Log selected config (without password)
    file_put_contents($logDir . '/phpsmtp_debug.log', date('c') . " CONFIG Selected: Host: $host Port: $port User: $user Secure: $secure" . PHP_EOL, FILE_APPEND);

    // Basic message fields
    $mail->isHTML(true);
    $mail->addAddress($recipient, 'esteemed customer');
    $mail->setFrom($from, $fromName);
    $mail->Subject = $subject;
    $mail->Body = $message;

    // Attach files if provided
    if (!empty($attachments) && is_array($attachments)) {
        foreach ($attachments as $filePath) {
            if (file_exists($filePath)) {
                $mail->addAttachment($filePath);
            }
        }
    }

    if (!$mail->send()) {
        $err = isset($mail->ErrorInfo) ? $mail->ErrorInfo : 'unknown';
        $context = isset($_POST) ? json_encode($_POST) : '';
        file_put_contents($logDir . '/email_errors.log', date('c') . " SEND_FAILED to: $recipient subject: $subject error: " . $err . " CONTEXT: " . $context . PHP_EOL, FILE_APPEND);
        return false;
    }

    return true;
}

?>