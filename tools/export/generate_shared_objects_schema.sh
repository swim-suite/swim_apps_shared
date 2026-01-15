#!/usr/bin/env bash
set -e

echo "🧠 Generating shared domain knowledge..."
echo "======================================="

# --------------------------------------------------
# Resolve repo root (swim_apps_shared)
# --------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

AI_CONTEXT_DIR="$ROOT_DIR/.ai_context"

DOMAIN_SCRIPT="$SCRIPT_DIR/export_domain_schema.py"
AREAS_SCRIPT="$SCRIPT_DIR/export_shared_areas.py"
MAP_SCRIPT="$SCRIPT_DIR/export_area_domain_map.py"

echo "📁 Script dir:   $SCRIPT_DIR"
echo "📁 Repo root:    $ROOT_DIR"
echo "📁 AI context:   $AI_CONTEXT_DIR"
echo ""

# --------------------------------------------------
# Sanity checks
# --------------------------------------------------
[ -d "$ROOT_DIR/lib" ] || { echo "❌ lib/ not found at $ROOT_DIR/lib"; exit 1; }
[ -f "$DOMAIN_SCRIPT" ] || { echo "❌ Missing export_domain_schema.py"; exit 1; }
[ -f "$AREAS_SCRIPT" ]  || { echo "❌ Missing export_shared_areas.py"; exit 1; }
[ -f "$MAP_SCRIPT" ]    || { echo "❌ Missing export_area_domain_map.py"; exit 1; }

mkdir -p "$AI_CONTEXT_DIR"

# --------------------------------------------------
# Run exports
# --------------------------------------------------
echo "🔄 Exporting domain schema..."
python3 "$DOMAIN_SCRIPT"

echo "🔄 Exporting areas..."
python3 "$AREAS_SCRIPT"

echo "🔄 Exporting area-domain map..."
python3 "$MAP_SCRIPT"

echo ""
echo "✅ Shared domain knowledge generated successfully."
echo "   → $AI_CONTEXT_DIR/swim_apps_shared_domain.json"
echo "   → $AI_CONTEXT_DIR/swim_apps_shared_areas.json"
echo "   → $AI_CONTEXT_DIR/swim_apps_shared_area_domain_map.json"
