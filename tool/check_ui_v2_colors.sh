#!/usr/bin/env bash
# Fails if new UI v2 code uses raw colours or fonts. Raw colours are allowed
# only in lib/design/app_tokens.dart and lib/business_profiles/.
# Colors.transparent is allowed.
set -u
cd "$(dirname "$0")/.."
DIRS="lib/design/components lib/shared_features lib/templates lib/features"
bad=$(grep -rnE "Color\(0x|Colors\.[a-zA-Z]+|GoogleFonts\." $DIRS --include=*.dart 2>/dev/null | grep -v "Colors\.transparent")
if [ -n "$bad" ]; then
  echo "UI v2 colour rule violated (use AppTokens):"
  echo "$bad"
  exit 1
fi
echo "UI v2 colour rule: OK"
