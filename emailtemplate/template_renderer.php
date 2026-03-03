<?php
// Lightweight template renderer shared by email API and workers.
// Provides tpl_get_value($data, $key) and tpl_render($tpl, $data)

function tpl_get_value($data, $key) {
    if ($key === '.') return $data;
    $parts = explode('.', $key);
    $val = $data;
    foreach ($parts as $p) {
        if (is_array($val) && array_key_exists($p, $val)) {
            $val = $val[$p];
        } else {
            return null;
        }
    }
    return $val;
}

function tpl_render($tpl, $data) {
    // Process section blocks {{#key}}...{{/key}}
    $pattern = '/{{#([\w\.]+)}}(.*?){{\/([\w\.]+)}}/s';
    while (preg_match($pattern, $tpl, $matches)) {
        $openKey = $matches[1];
        $block = $matches[2];
        $closeKey = $matches[3];
        if ($openKey !== $closeKey) break;

        $arr = tpl_get_value($data, $openKey);
        $replacement = '';
        if (is_array($arr)) {
            foreach ($arr as $item) {
                if (is_array($item)) {
                    $merged = array_merge(is_array($data) ? $data : [], $item);
                    $replacement .= tpl_render($block, $merged);
                } else {
                    $merged = is_array($data) ? $data : [];
                    $merged['.'] = $item;
                    $replacement .= tpl_render($block, $merged);
                }
            }
        }

        $tpl = preg_replace($pattern, str_replace('\$', '\\\$', $replacement), $tpl, 1);
    }

    // Replace variables {{ key }} with values
    $tpl = preg_replace_callback('/{{\s*([\w\.]+)\s*}}/', function($m) use ($data) {
        $val = tpl_get_value($data, $m[1]);
        if (is_null($val)) return '';
        if (is_array($val)) return '';
        return htmlspecialchars((string)$val, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
    }, $tpl);

    return $tpl;
}

?>
