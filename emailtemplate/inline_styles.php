<?php
/**
 * Simple CSS inliner for email templates.
 *
 * Usage: require_once 'inline_styles.php';
 *        $inlined = inline_css($html_fragment, $global_css_string);
 *
 * Note: This is a lightweight implementation intended for common selectors
 * (element, .class, #id, tag.class). It does not implement full CSS cascade
 * or specificity rules but is sufficient for email templates that use
 * straightforward selectors.
 */

function inline_css($html, $global_css = '') {
    // Wrap fragment in container so DOMDocument parses correctly
    $is_full_doc = preg_match('/<\/?html[\s>]/i', $html) === 1;
    $wrapper_open = $is_full_doc ? '' : '<div id="__inline_root__">';
    $wrapper_close = $is_full_doc ? '' : '</div>';

    $doc = new DOMDocument();
    libxml_use_internal_errors(true);
    $doc->loadHTML('<?xml encoding="utf-8" ?>' . $wrapper_open . $html . $wrapper_close);
    libxml_clear_errors();

    // Collect styles from any style tags present in the fragment
    $styles = $global_css;
    $styleTags = $doc->getElementsByTagName('style');
    for ($i = 0; $i < $styleTags->length; $i++) {
        $styles .= "\n" . $styleTags->item($i)->nodeValue;
    }

    // Parse simple CSS rules
    $rules = parse_css_rules($styles);

    $xpath = new DOMXPath($doc);

    foreach ($rules as $selector => $declarations) {
        $selector = trim($selector);
        if ($selector === '') continue;
        // Support comma-separated selectors
        $parts = preg_split('/\s*,\s*/', $selector);
        foreach ($parts as $sel) {
            $sel = trim($sel);
            if ($sel === '') continue;

            // Build XPath for simple selectors
            $query = selector_to_xpath($sel);
            if ($query === null) continue; // unsupported selector

            $nodes = $xpath->query($query);
            if ($nodes === false) continue;
            foreach ($nodes as $node) {
                if (!$node instanceof DOMElement) continue;
                // Merge styles, keeping existing inline styles as higher priority
                $existing = $node->getAttribute('style');
                $merged = merge_css_styles($declarations, $existing);
                $node->setAttribute('style', $merged);
            }
        }
    }

    // Remove style tags as we have inlined them
    $styleTags = $doc->getElementsByTagName('style');
    // Need to remove in reverse order
    for ($i = $styleTags->length - 1; $i >= 0; $i--) {
        $node = $styleTags->item($i);
        $node->parentNode->removeChild($node);
    }

    // Extract back the inner HTML of wrapper if we added one
    if (!$is_full_doc) {
        $root = $doc->getElementById('__inline_root__');
        if ($root) {
            $inner = '';
            foreach ($root->childNodes as $child) {
                $inner .= $doc->saveHTML($child);
            }
            return $inner;
        }
    }

    return $doc->saveHTML();
}

function parse_css_rules($css) {
    $rules = [];
    // Remove comments
    $css = preg_replace('!/\*.*?\*/!s', '', $css);
    // Match blocks
    preg_match_all('/([^{]+)\{([^}]+)\}/s', $css, $matches, PREG_SET_ORDER);
    foreach ($matches as $m) {
        $selector = trim($m[1]);
        $body = trim($m[2]);
        // Normalize declarations
        $decls = [];
        foreach (explode(';', $body) as $d) {
            if (strpos($d, ':') === false) continue;
            list($prop, $val) = explode(':', $d, 2);
            $prop = trim($prop);
            $val = trim($val);
            if ($prop !== '') $decls[$prop] = $val;
        }
        if (!empty($decls)) $rules[$selector] = $decls;
    }
    return $rules;
}

function selector_to_xpath($sel) {
    // Handle id selector: #id
    if (preg_match('/^#([A-Za-z0-9_\-]+)$/', $sel, $m)) {
        $id = $m[1];
        return "//*[@id='" . $id . "']";
    }
    // Handle class selector: .class
    if (preg_match('/^\.([A-Za-z0-9_\-]+)$/', $sel, $m)) {
        $cls = $m[1];
        return "//*[contains(concat(' ', normalize-space(@class), ' '), ' " . $cls . " ')]";
    }
    // Handle tag.class (e.g., div.header)
    if (preg_match('/^([A-Za-z0-9]+)\.([A-Za-z0-9_\-]+)$/', $sel, $m)) {
        $tag = $m[1]; $cls = $m[2];
        return "//" . $tag . "[contains(concat(' ', normalize-space(@class), ' '), ' " . $cls . " ')]";
    }
    // Handle simple tag selectors
    if (preg_match('/^[A-Za-z0-9]+$/', $sel)) {
        return '//' . $sel;
    }
    // Unsupported or complex selector
    return null;
}

function merge_css_styles($ruleDecls, $existingStyle) {
    $existing = [];
    foreach (explode(';', $existingStyle) as $part) {
        if (strpos($part, ':') === false) continue;
        list($p, $v) = explode(':', $part, 2);
        $p = trim($p); $v = trim($v);
        if ($p !== '') $existing[$p] = $v;
    }

    // Apply rule declarations only if not present in existing inline styles
    $merged = $existing;
    foreach ($ruleDecls as $p => $v) {
        if (!array_key_exists($p, $existing)) {
            $merged[$p] = $v;
        }
    }

    $out = '';
    foreach ($merged as $p => $v) {
        $out .= $p . ': ' . $v . '; ';
    }
    return trim($out);
}
