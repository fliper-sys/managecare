<?php
// Receipt wrapper template. Expects $data array with keys used by receipt_template.php helpers.
require_once __DIR__ . '/../receipt_template.php';

// If caller passed $data as an array, use it; otherwise try to gather variables defined in scope
$receiptData = $data ?? [];

// Render and output full receipt HTML
echo render_complete_receipt_html($receiptData);
?>