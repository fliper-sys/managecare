<?php
// Daily Transactions Email Template
// Expects $businessName (string), $date (string), $transactions (array of ['type','amount','note'])
$businessName = htmlspecialchars($businessName ?? ($data['businessName'] ?? 'Your Business'), ENT_QUOTES, 'UTF-8');
$date = htmlspecialchars($date ?? ($data['date'] ?? date('Y-m-d')), ENT_QUOTES, 'UTF-8');
$transactions = $transactions ?? ($data['transactions'] ?? []);

ob_start();
?>
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { font-family: Arial, sans-serif; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #1e3a8a; color: white; padding: 20px; border-radius: 6px; }
    .transactions { margin-top: 15px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { padding: 8px 6px; border-bottom: 1px solid #eee; }
    th { text-align: left; background: #f5f7fb; }
    .total { font-weight: bold; font-size: 16px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h2><?php echo $businessName; ?></h2>
      <p style="margin:0;">Daily Transactions Report — <?php echo $date; ?></p>
    </div>

    <div class="transactions">
      <table>
        <thead>
          <tr>
            <th>Description</th>
            <th style="text-align:right">Amount</th>
          </tr>
        </thead>
        <tbody>
          <?php
          $grand = 0;
          if (!empty($transactions) && is_array($transactions)) {
            foreach ($transactions as $t) {
              $desc = htmlspecialchars($t['note'] ?? $t['type'] ?? '', ENT_QUOTES, 'UTF-8');
              $amt = floatval($t['amount'] ?? 0);
              $grand += $amt;
              echo "<tr><td>{$desc}</td><td style='text-align:right'>" . number_format($amt,2) . "</td></tr>";
            }
          } else {
            echo "<tr><td colspan=2><em>No transactions recorded for this period.</em></td></tr>";
          }
          ?>
        </tbody>
        <tfoot>
          <tr>
            <td class="total">Total</td>
            <td class="total" style="text-align:right"><?php echo number_format($grand, 2); ?></td>
          </tr>
        </tfoot>
      </table>
    </div>

    <p style="margin-top:20px; color:#666; font-size:13px;">This is an automated message from Manage Care. For assistance, reply to this email.</p>
  </div>
</body>
</html>
<?php
$html = ob_get_clean();
// Output the HTML for email renderer
echo $html;
?>