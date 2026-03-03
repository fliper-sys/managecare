<?php
/**
 * Receipt Email Template Processor
 * Handles rendering of receipt templates with subscription-aware styling
 * 
 * This processes receipt data and creates branded HTML emails with:
 * - Theme support (professional, casual, dark, light)
 * - Business branding (logo, colors, contact info)
 * - Item-level details with pricing
 * - Customer personalization
 * - Payment method display
 * - Tax and discount calculations
 * - Multi-language support (future)
 */

/**
 * Generate detailed receipt template with itemization
 */
function render_receipt_template_detailed($receiptData) {
    extract($receiptData);
    
    $itemsHtml = '';
    if (isset($items) && is_array($items)) {
        $itemsHtml = '<table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">';
        $itemsHtml .= '<thead style="background: #f5f5f5; border-bottom: 2px solid #ddd;">';
        $itemsHtml .= '<tr>';
        $itemsHtml .= '<th style="padding: 8px; text-align: left; font-weight: bold;">Item</th>';
        $itemsHtml .= '<th style="padding: 8px; text-align: center; font-weight: bold;">Qty</th>';
        $itemsHtml .= '<th style="padding: 8px; text-align: right; font-weight: bold;">Unit Price</th>';
        $itemsHtml .= '<th style="padding: 8px; text-align: right; font-weight: bold;">Amount</th>';
        $itemsHtml .= '</tr>';
        $itemsHtml .= '</thead>';
        $itemsHtml .= '<tbody>';
        
        $subtotal = 0;
        foreach ($items as $item) {
            $name = htmlspecialchars($item['name'] ?? 'Item', ENT_QUOTES, 'UTF-8');
            $qty = $item['quantity'] ?? 1;
            $price = $item['price'] ?? 0;
            $amount = $qty * $price;
            $subtotal += $amount;
            
            $itemsHtml .= '<tr style="border-bottom: 1px solid #eee;">';
            $itemsHtml .= '<td style="padding: 8px;">' . $name . '</td>';
            $itemsHtml .= '<td style="padding: 8px; text-align: center;">' . $qty . '</td>';
            $itemsHtml .= '<td style="padding: 8px; text-align: right;">' . number_format($price, 2) . '</td>';
            $itemsHtml .= '<td style="padding: 8px; text-align: right; font-weight: bold;">' . number_format($amount, 2) . '</td>';
            $itemsHtml .= '</tr>';
        }
        
        $itemsHtml .= '</tbody>';
        $itemsHtml .= '</table>';
    }
    
    return $itemsHtml;
}

/**
 * Generate payment summary section
 */
function render_payment_summary($receiptData) {
    extract($receiptData);
    
    $subtotal = $receiptData['subtotal'] ?? 0;
    $tax = $receiptData['tax'] ?? 0;
    $discount = $receiptData['discount'] ?? 0;
    $total = $receiptData['total'] ?? 0;
    $paymentMethod = $receiptData['paymentMethod'] ?? 'Cash';
    $currency = $receiptData['currency'] ?? '₦';
    
    $summaryHtml = '<div style="margin: 20px 0; padding: 15px; background: #f9f9f9; border-radius: 3px;">';
    $summaryHtml .= '<table style="width: 100%; border-collapse: collapse; font-size: 14px;">';
    
    // Subtotal
    $summaryHtml .= '<tr>';
    $summaryHtml .= '<td style="padding: 5px 0;">Subtotal:</td>';
    $summaryHtml .= '<td style="padding: 5px 0; text-align: right;">' . $currency . number_format($subtotal, 2) . '</td>';
    $summaryHtml .= '</tr>';
    
    // Tax
    if ($tax > 0) {
        $summaryHtml .= '<tr>';
        $summaryHtml .= '<td style="padding: 5px 0;">Tax:</td>';
        $summaryHtml .= '<td style="padding: 5px 0; text-align: right;">+' . $currency . number_format($tax, 2) . '</td>';
        $summaryHtml .= '</tr>';
    }
    
    // Discount
    if ($discount > 0) {
        $summaryHtml .= '<tr>';
        $summaryHtml .= '<td style="padding: 5px 0;">Discount:</td>';
        $summaryHtml .= '<td style="padding: 5px 0; text-align: right;">-' . $currency . number_format($discount, 2) . '</td>';
        $summaryHtml .= '</tr>';
    }
    
    // Total (bold)
    $summaryHtml .= '<tr style="border-top: 2px solid #ddd; margin-top: 10px;">';
    $summaryHtml .= '<td style="padding: 10px 0; font-weight: bold; font-size: 16px;">Total:</td>';
    $summaryHtml .= '<td style="padding: 10px 0; text-align: right; font-weight: bold; font-size: 16px;">' . $currency . number_format($total, 2) . '</td>';
    $summaryHtml .= '</tr>';
    
    $summaryHtml .= '</table>';
    
    // Payment Method
    $summaryHtml .= '<div style="margin-top: 15px; padding-top: 15px; border-top: 1px solid #ddd; font-size: 12px;">';
    $summaryHtml .= 'Payment Method: <strong>' . htmlspecialchars($paymentMethod, ENT_QUOTES, 'UTF-8') . '</strong>';
    $summaryHtml .= '</div>';
    
    $summaryHtml .= '</div>';
    
    return $summaryHtml;
}

/**
 * Generate customer and business info section
 */
function render_receipt_info($receiptData) {
    extract($receiptData);
    
    $infoHtml = '<div style="margin: 20px 0; font-size: 12px; color: #666;">';
    
    // Receipt number and date
    $infoHtml .= '<p style="margin: 5px 0;">';
    if (isset($receiptNumber)) {
        $infoHtml .= 'Receipt #: ' . htmlspecialchars($receiptNumber, ENT_QUOTES, 'UTF-8') . '<br>';
    }
    if (isset($date)) {
        $infoHtml .= 'Date: ' . htmlspecialchars($date, ENT_QUOTES, 'UTF-8') . '<br>';
    }
    if (isset($time)) {
        $infoHtml .= 'Time: ' . htmlspecialchars($time, ENT_QUOTES, 'UTF-8') . '<br>';
    }
    $infoHtml .= '</p>';
    
    // Customer info
    if (isset($customerName)) {
        $infoHtml .= '<p style="margin: 5px 0;">';
        $infoHtml .= 'Customer: ' . htmlspecialchars($customerName, ENT_QUOTES, 'UTF-8') . '<br>';
        if (isset($customerEmail)) {
            $infoHtml .= 'Email: ' . htmlspecialchars($customerEmail, ENT_QUOTES, 'UTF-8') . '<br>';
        }
        if (isset($customerPhone)) {
            $infoHtml .= 'Phone: ' . htmlspecialchars($customerPhone, ENT_QUOTES, 'UTF-8') . '<br>';
        }
        $infoHtml .= '</p>';
    }
    
    // Cashier/Staff
    if (isset($staffName)) {
        $infoHtml .= '<p style="margin: 5px 0;">Staff: ' . htmlspecialchars($staffName, ENT_QUOTES, 'UTF-8') . '</p>';
    }
    
    $infoHtml .= '</div>';
    
    return $infoHtml;
}

/**
 * Generate subscription receipt badge (Pro feature visual)
 */
function render_subscription_badge($receiptData) {
    if (!isset($receiptData['isSubscriptionReceipt']) || !$receiptData['isSubscriptionReceipt']) {
        return '';
    }
    
    $badge = '<div style="display: inline-block; background: #7c3aed; color: white; padding: 5px 12px; border-radius: 20px; font-size: 11px; font-weight: bold; margin-bottom: 15px;">';
    $badge .= '✓ SUBSCRIPTION RECEIPT';
    $badge .= '</div>';
    
    return $badge;
}

/**
 * Generate payment terms (for invoices)
 */
function render_payment_terms($receiptData) {
    if (!isset($receiptData['isInvoice']) || !$receiptData['isInvoice']) {
        return '';
    }
    
    $termsHtml = '<div style="margin: 20px 0; padding: 15px; background: #fef3c7; border-left: 3px solid #f59e0b; border-radius: 3px;">';
    $termsHtml .= '<strong>Payment Terms:</strong><br>';
    
    if (isset($receiptData['dueDate'])) {
        $termsHtml .= 'Due Date: ' . htmlspecialchars($receiptData['dueDate'], ENT_QUOTES, 'UTF-8') . '<br>';
    }
    
    if (isset($receiptData['notes'])) {
        $termsHtml .= 'Notes: ' . htmlspecialchars($receiptData['notes'], ENT_QUOTES, 'UTF-8') . '<br>';
    }
    
    $termsHtml .= '</div>';
    
    return $termsHtml;
}

/**
 * Generate footer with business info and legal
 */
function render_receipt_footer($receiptData) {
    extract($receiptData);
    
    $footerHtml = '<div style="margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 11px; color: #999; text-align: center;">';
    
    // Business tagline or thanks
    if (isset($businessTagline)) {
        $footerHtml .= '<p style="margin: 10px 0;">' . htmlspecialchars($businessTagline, ENT_QUOTES, 'UTF-8') . '</p>';
    }
    
    // Social links (if available)
    if (isset($businessWebsite)) {
        $footerHtml .= '<p style="margin: 5px 0;"><a href="' . htmlspecialchars($businessWebsite, ENT_QUOTES, 'UTF-8') . '" style="color: #0066cc; text-decoration: none;">Visit our website</a></p>';
    }
    
    // Compliance notice
    $footerHtml .= '<p style="margin: 10px 0; color: #ccc; font-size: 10px;">';
    $footerHtml .= 'This receipt was automatically generated by Manage Care.<br>';
    $footerHtml .= 'Please retain this email as proof of purchase.';
    $footerHtml .= '</p>';
    
    $footerHtml .= '</div>';
    
    return $footerHtml;
}

/**
 * Render complete receipt HTML
 */
function render_complete_receipt_html($receiptData) {
    $colors = get_theme_colors($receiptData['theme'] ?? 'professional');
    
    $html = '<!DOCTYPE html><html><head>';
    $html .= '<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">';
    $html .= '<style>';
    $html .= 'body { font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }';
    $html .= '.container { max-width: 600px; margin: 0 auto; padding: 20px; background: #f9f9f9; }';
    $html .= '.wrapper { background: white; border-radius: 5px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }';
    $html .= '.header { background: ' . $colors['primary'] . '; color: white; padding: 30px 20px; text-align: center; border-radius: 5px 5px 0 0; }';
    $html .= '.header h1 { margin: 0 0 5px 0; font-size: 24px; }';
    $html .= '.header p { margin: 0; opacity: 0.9; }';
    $html .= '.content { padding: 30px 20px; }';
    $html .= '.footer { background: #f5f5f5; padding: 20px; border-radius: 0 0 5px 5px; }';
    $html .= 'a { color: ' . $colors['accent'] . '; text-decoration: none; }';
    $html .= 'a:hover { text-decoration: underline; }';
    $html .= '</style>';
    $html .= '</head><body>';
    
    $html .= '<div class="container">';
    $html .= '<div class="wrapper">';
    
    // Header with business info
    if (isset($receiptData['logoUrl'])) {
        $html .= '<div style="text-align: center; padding: 10px;"><img src="' . htmlspecialchars($receiptData['logoUrl'], ENT_QUOTES, 'UTF-8') . '" alt="Logo" style="max-height: 80px; max-width: 200px;"></div>';
    }
    
    $html .= '<div class="header">';
    $html .= '<h1>' . htmlspecialchars($receiptData['businessName'] ?? 'Receipt', ENT_QUOTES, 'UTF-8') . '</h1>';
    $html .= '<p>Receipt Confirmation</p>';
    if (isset($receiptData['businessAddress'])) {
        $html .= '<p style="font-size: 12px;">' . htmlspecialchars($receiptData['businessAddress'], ENT_QUOTES, 'UTF-8') . '</p>';
    }
    $html .= '</div>';
    
    // Content
    $html .= '<div class="content">';
    
    // Greeting
    $customerName = $receiptData['customerName'] ?? 'Valued Customer';
    $html .= '<p>Dear ' . htmlspecialchars($customerName, ENT_QUOTES, 'UTF-8') . ',</p>';
    $html .= '<p>Thank you for your purchase! Here is your receipt:</p>';
    
    // Subscription badge
    $html .= render_subscription_badge($receiptData);
    
    // Items table
    if (isset($receiptData['items']) && !empty($receiptData['items'])) {
        $html .= render_receipt_template_detailed($receiptData);
    }
    
    // Payment summary
    if (isset($receiptData['total'])) {
        $html .= render_payment_summary($receiptData);
    }
    
    // Payment terms (for invoices)
    $html .= render_payment_terms($receiptData);
    
    // Receipt info
    $html .= render_receipt_info($receiptData);
    
    $html .= '</div>';
    
    // Footer
    $html .= '<div class="footer">';
    $html .= render_receipt_footer($receiptData);
    $html .= '</div>';
    
    $html .= '</div></div></body></html>';
    
    return $html;
}

// Make helper function available to email_api.php
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

?>
