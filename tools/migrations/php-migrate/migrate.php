<?php
// migrate.php
// Firestore migration script (PHP CLI)
// Purpose: Populate `businessIds` (array) and `currentBusinessId` on user documents
// Usage:
//  php migrate.php --sa=service-account.json --dry-run --out=report.json
//  php migrate.php --sa=service-account.json --apply --out=report.json --create-missing

set_time_limit(0);
error_reporting(E_ALL);

function usage() {
    $msg = <<<USAGE
Usage: php migrate.php --sa=service-account.json [--dry-run|--apply] [--out=report.json] [--create-missing]

Options:
  --sa=PATH           Path to service account JSON file (required)
  --dry-run           Run without writing changes (default if neither dry-run nor apply passed)
  --apply             Apply changes to Firestore
  --out=PATH          Output report file path (default: migration_report.json)
  --create-missing    Create missing user documents when needed
  --help              Show this help

Examples:
  php migrate.php --sa=sa.json --dry-run --out=report.json
  php migrate.php --sa=sa.json --apply --out=report.json --create-missing
USAGE;
    echo $msg . PHP_EOL;
    exit(1);
}

// Simple CLI args parsing
$opts = [];
foreach ($argv as $arg) {
    if (preg_match('/^--([^=]+)=(.*)$/', $arg, $m)) {
        $opts[$m[1]] = $m[2];
    } elseif (preg_match('/^--(.*)$/', $arg, $m)) {
        $opts[$m[1]] = true;
    }
}

if (isset($opts['help']) || !isset($opts['sa'])) {
    usage();
}

$saPath = $opts['sa'];
$dryRun = isset($opts['dry-run']) && !$opts['apply'];
$apply = isset($opts['apply']);
$outPath = isset($opts['out']) ? $opts['out'] : 'migration_report.json';
$createMissing = isset($opts['create-missing']);
$yes = isset($opts['yes']);
$configPath = isset($opts['config']) ? $opts['config'] : (file_exists('config.json') ? 'config.json' : null);

if (!file_exists($saPath)) {
    fwrite(STDERR, "Service account file not found: $saPath" . PHP_EOL);
    exit(2);
}

$saJson = json_decode(file_get_contents($saPath), true);
if (!$saJson) {
    fwrite(STDERR, "Failed to read/parse service account JSON: $saPath" . PHP_EOL);
    exit(2);
}

// Default schema config (can be overridden by --config=path)
$defaultConfig = [
    'businessesCollection' => 'businesses',
    'usersCollection' => 'users',
    'ownerFieldNames' => ['owners','owner','ownerId','ownerIds'],
    'ownersArrayFieldNames' => ['owners','ownerIds'],
    'memberSubcollections' => ['members','workers','staff'],
    'memberUserIdFields' => ['userId','uid','id','workerId','user','owner'],
    'userEmailFieldNames' => ['email','emailAddress']
];

$config = $defaultConfig;
if ($configPath && file_exists($configPath)) {
    $userConfig = json_decode(file_get_contents($configPath), true);
    if ($userConfig && is_array($userConfig)) {
        $config = array_replace_recursive($config, $userConfig);
        echo "Loaded configuration from $configPath\n";
    } else {
        echo "Warning: failed to parse config at $configPath, using defaults.\n";
    }
}

$projectId = $saJson['project_id'] ?? null;
if (!$projectId) {
    fwrite(STDERR, "project_id not found in service account JSON" . PHP_EOL);
    exit(2);
}

function base64url_encode($data) {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

function create_jwt_assertion($saJson) {
    $now = time();
    $header = ['alg' => 'RS256', 'typ' => 'JWT'];
    $claims = [
        'iss' => $saJson['client_email'],
        'scope' => 'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/cloud-platform',
        'aud' => 'https://oauth2.googleapis.com/token',
        'exp' => $now + 3600,
        'iat' => $now
    ];

    $header_b64 = base64url_encode(json_encode($header));
    $claims_b64 = base64url_encode(json_encode($claims));
    $unsigned = $header_b64 . '.' . $claims_b64;

    $private_key = $saJson['private_key'] ?? null;
    if (!$private_key) {
        fwrite(STDERR, "private_key not found in service account JSON" . PHP_EOL);
        exit(2);
    }

    $signature = null;
    $ok = openssl_sign($unsigned, $signature, $private_key, OPENSSL_ALGO_SHA256);
    if (!$ok) {
        fwrite(STDERR, "Failed to sign JWT with private key" . PHP_EOL);
        exit(2);
    }
    $sig_b64 = base64url_encode($signature);
    return $unsigned . '.' . $sig_b64;
}

function get_access_token($saJson) {
    $assertion = create_jwt_assertion($saJson);
    $post = http_build_query([
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion' => $assertion
    ]);
    $ch = curl_init('https://oauth2.googleapis.com/token');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $post);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);
    $resp = curl_exec($ch);
    if ($resp === false) {
        fwrite(STDERR, "Failed to fetch access token: " . curl_error($ch) . PHP_EOL);
        exit(2);
    }
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    $data = json_decode($resp, true);
    if (!$data || !isset($data['access_token'])) {
        fwrite(STDERR, "Invalid token response: $resp" . PHP_EOL);
        exit(2);
    }
    return $data['access_token'];
}

function api_get($url, $accessToken) {
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ["Authorization: Bearer $accessToken"]);
    $resp = curl_exec($ch);
    if ($resp === false) {
        throw new Exception('HTTP request failed: ' . curl_error($ch));
    }
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return [$code, $resp];
}

function api_patch($url, $accessToken, $jsonBody) {
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PATCH');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ["Authorization: Bearer $accessToken", 'Content-Type: application/json']);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($jsonBody));
    $resp = curl_exec($ch);
    if ($resp === false) {
        throw new Exception('HTTP request failed: ' . curl_error($ch));
    }
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return [$code, $resp];
}

function extract_doc_id($documentName) {
    // documentName like: projects/{project}/databases/(default)/documents/businesses/{docId}
    $parts = explode('/', $documentName);
    return end($parts);
}

$accessToken = get_access_token($saJson);
$project = $projectId;
$base = "https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents";

// --- Fetch businesses ---
function list_collection($base, $collection, $accessToken) {
    $documents = [];
    $pageToken = null;
    do {
        $url = "$base/$collection?pageSize=200";
        if ($pageToken) $url .= "&pageToken="$pageToken;
        list($code, $resp) = api_get($url, $accessToken);
        if ($code !== 200) {
            throw new Exception("Failed to list $collection: HTTP $code - $resp");
        }
        $data = json_decode($resp, true);
        if (isset($data['documents'])) {
            $documents = array_merge($documents, $data['documents']);
        }
        $pageToken = $data['nextPageToken'] ?? null;
    } while ($pageToken);
    return $documents;
}

echo "Listing businesses from collection {$config['businessesCollection']}...\n";
$businessDocs = list_collection($base, $config['businessesCollection'], $accessToken);
echo "Found " . count($businessDocs) . " business documents\n";

$report = [
    'project' => $project,
    'timestamp' => date(DATE_ATOM),
    'businessCount' => count($businessDocs),
    'changes' => [],
    'errors' => []
];

function get_field_string($field) {
    if (!isset($field)) return null;
    if (isset($field['stringValue'])) return $field['stringValue'];
    return null;
}

function get_array_strings($field) {
    if (!isset($field)) return [];
    $values = $field['arrayValue']['values'] ?? [];
    $out = [];
    foreach ($values as $v) {
        if (isset($v['stringValue'])) $out[] = $v['stringValue'];
    }
    return $out;
}

function list_subcollection($base, $parentCollection, $docId, $subcollection, $accessToken) {
    $url = "$base/$parentCollection/$docId/$subcollection?pageSize=200";
    list($code, $resp) = api_get($url, $accessToken);
    if ($code === 200) {
        $data = json_decode($resp, true);
        return $data['documents'] ?? [];
    }
    // Not necessarily an error — subcollection may not exist
    return [];
}

// Build mapping businessId -> userIds (flexible, based on config)
$businessUserMap = [];
foreach ($businessDocs as $bdoc) {
    $bname = $bdoc['name'] ?? null;
    if (!$bname) continue;
    $bid = extract_doc_id($bname);
    $fields = $bdoc['fields'] ?? [];

    $usersFound = [];
    // Check owner fields (either arrays or single string fields)
    foreach ($config['ownerFieldNames'] as $ownerField) {
        if (isset($fields[$ownerField])) {
            // If it's an array field name listed in ownersArrayFieldNames
            if (in_array($ownerField, $config['ownersArrayFieldNames'])) {
                $vals = get_array_strings($fields[$ownerField]);
                foreach ($vals as $v) if (!empty($v)) $usersFound[] = $v;
            } else {
                $single = get_field_string($fields[$ownerField] ?? null);
                if ($single) $usersFound[] = $single;
            }
        }
    }

    // Look for configured member subcollections
    $subs = [];
    foreach ($config['memberSubcollections'] as $subcol) {
        $sdocs = list_subcollection($base, $config['businessesCollection'], $bid, $subcol, $accessToken);
        if ($sdocs) $subs = array_merge($subs, $sdocs);
    }

    foreach ($subs as $m) {
        $mf = $m['fields'] ?? [];
        // Look for a user id in the candidate fields
        $found = false;
        foreach ($config['memberUserIdFields'] as $uidField) {
            $uid = get_field_string($mf[$uidField] ?? null);
            if ($uid) {
                $usersFound[] = $uid;
                $found = true;
                break;
            }
        }
        if (!$found) {
            // fallback: check for email fields
            foreach ($config['userEmailFieldNames'] as $emailField) {
                $email = get_field_string($mf[$emailField] ?? null);
                if ($email) {
                    $usersFound[] = $email;
                    break;
                }
            }
        }
    }

    $userIds = array_values(array_unique(array_filter($usersFound)));
    $businessUserMap[$bid] = $userIds;
}

// Invert map to userId -> [businessId]
$userToBusinesses = [];
foreach ($businessUserMap as $bid => $userIds) {
    foreach ($userIds as $uid) {
        if (!isset($userToBusinesses[$uid])) $userToBusinesses[$uid] = [];
        $userToBusinesses[$uid][] = $bid;
    }
}

echo "Found " . count($userToBusinesses) . " unique users referenced by businesses" . PHP_EOL;

// If apply requested, require explicit confirmation unless --yes passed
if ($apply && !$yes) {
    echo "\nAPPLY MODE: You are about to patch user documents in Firestore.\n";
    echo "This is destructive and irreversible — type APPLY to continue: ";
    $handle = fopen("php://stdin", "r");
    $line = trim(fgets($handle));
    if ($line !== 'APPLY') {
        echo "Confirmation failed. Aborting.\n";
        exit(3);
    }
}

// Helper to fetch user doc by id
function get_user_doc($base, $uid, $accessToken) {
    $url = "$base/{$GLOBALS['config']['usersCollection']}/" . rawurlencode($uid);
    list($code, $resp) = api_get($url, $accessToken);
    if ($code === 200) {
        return json_decode($resp, true);
    }
    return null;
}

// Helper to query users by email (if user id looks like email)
function find_user_by_email($base, $email, $accessToken, $project) {
    // Use runQuery to search for field email == email
    $query = [
        'structuredQuery' => [
            'from' => [[ 'collectionId' => 'users' ]],
            'where' => [
                'fieldFilter' => [
                    'field' => ['fieldPath' => 'email'],
                    'op' => 'EQUAL',
                    'value' => ['stringValue' => $email]
                ]
            ],
            'limit' => 1
        ]
    ];
    $url = "https://firestore.googleapis.com/v1/projects/$project/databases/(default)/documents:runQuery";
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ["Authorization: Bearer $accessToken", 'Content-Type: application/json']);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($query));
    $resp = curl_exec($ch);
    if ($resp === false) return null;
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    if ($code !== 200) return null;
    $items = json_decode($resp, true);
    if (!$items || !is_array($items) || count($items) === 0) return null;
    foreach ($items as $row) {
        if (isset($row['document'])) return $row['document'];
    }
    return null;
}

// Prepare changes list
$changes = [];
foreach ($userToBusinesses as $uid => $bids) {
    $change = ['userId' => $uid, 'businessesFound' => $bids, 'action' => 'noop', 'note' => ''];
    // Try fetch user doc as document id
    $userDoc = get_user_doc($base, $uid, $accessToken);
    if (!$userDoc && strpos($uid, '@') !== false) {
        // try to find by email
        $maybe = find_user_by_email($base, $uid, $accessToken, $project);
        if ($maybe) {
            $userDoc = $maybe;
        }
    }

    if (!$userDoc) {
        $change['action'] = 'missing';
        $change['note'] = 'User document not found';
        $change['existing'] = null;
        // If createMissing, prepare create
        if ($createMissing && $apply) {
            // Create user doc with minimal fields
            try {
                $docPath = "$base/users/" . rawurlencode($uid);
                $fields = [
                    'businessIds' => ['arrayValue' => ['values' => array_map(function($v){ return ['stringValue' => $v]; }, $bids)]],
                    'currentBusinessId' => ['stringValue' => $bids[0]]
                ];
                $jsonBody = ['fields' => $fields];
                list($pc, $pResp) = api_patch($docPath, $accessToken, $jsonBody);
                if ($pc >= 200 && $pc < 300) {
                    $change['action'] = 'created';
                    $change['note'] = 'Created missing user doc';
                } else {
                    $change['action'] = 'error';
                    $change['note'] = "Failed to create user doc: HTTP $pc - $pResp";
                }
            } catch (Exception $e) {
                $change['action'] = 'error';
                $change['note'] = 'Exception: ' . $e->getMessage();
            }
        }
        $changes[] = $change;
        continue;
    }

    $existingBusinessIds = get_array_strings($userDoc['fields']['businessIds'] ?? null);
    $existingCurrent = get_field_string($userDoc['fields']['currentBusinessId'] ?? $userDoc['fields']['businessId'] ?? null);

    // Merge
    $merged = array_values(array_unique(array_merge($existingBusinessIds, $bids)));
    $newCurrent = $existingCurrent ?: ($merged[0] ?? null);

    if ($merged === $existingBusinessIds && $newCurrent === $existingCurrent) {
        $change['action'] = 'noop';
        $change['existing'] = ['businessIds' => $existingBusinessIds, 'current' => $existingCurrent];
        $changes[] = $change;
        continue;
    }

    $change['existing'] = ['businessIds' => $existingBusinessIds, 'current' => $existingCurrent];
    $change['proposed'] = ['businessIds' => $merged, 'current' => $newCurrent];

    if ($apply) {
        // perform PATCH update
        try {
            $docPath = "$base/users/" . rawurlencode(extract_doc_id($userDoc['name']));
            $jsonBody = [
                'fields' => [
                    'businessIds' => ['arrayValue' => ['values' => array_map(function ($v) { return ['stringValue' => $v]; }, $merged)]],
                ]
            ];
            if ($newCurrent) {
                $jsonBody['fields']['currentBusinessId'] = ['stringValue' => $newCurrent];
            }
            // UpdateMask to limit fields
            $url = $docPath . '?updateMask.fieldPaths=businessIds';
            if ($newCurrent) $url .= '&updateMask.fieldPaths=currentBusinessId';

            list($pc, $pResp) = api_patch($url, $accessToken, $jsonBody);
            if ($pc >= 200 && $pc < 300) {
                $change['action'] = 'updated';
                $change['note'] = 'Patched user document successfully';
            } else {
                $change['action'] = 'error';
                $change['note'] = "Patch failed: HTTP $pc - $pResp";
            }
        } catch (Exception $e) {
            $change['action'] = 'error';
            $change['note'] = 'Exception: ' . $e->getMessage();
        }
    } else {
        $change['action'] = 'planned';
        $change['note'] = 'Dry-run: no changes applied';
    }

    $changes[] = $change;
}

$report['changes'] = $changes;
$report['summary'] = [
    'planned' => count(array_filter($changes, function($c){ return $c['action'] === 'planned'; })),
    'updated' => count(array_filter($changes, function($c){ return $c['action'] === 'updated' || $c['action'] === 'created'; })),
    'noop' => count(array_filter($changes, function($c){ return $c['action'] === 'noop'; })),
    'missing' => count(array_filter($changes, function($c){ return $c['action'] === 'missing'; })),
    'errors' => count(array_filter($changes, function($c){ return $c['action'] === 'error'; })),
];

file_put_contents($outPath, json_encode($report, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

echo "Report written to $outPath\n";
echo "Summary: ";
print_r($report['summary']);

echo "Done.\n";

?>
