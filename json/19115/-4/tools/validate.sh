#!/bin/sh

# validation using https://www.npmjs.com/package/ajv-cli and https://www.npmjs.com/package/ajv-formats
# NOTE: strict must be false, otherwise "$anchor" is not recognized; see https://github.com/ajv-validator/ajv/issues/1854
#
# Run from any directory. Paths are resolved relative to this script's location.
#   tools/ is at: json/19115/-4/tools/
#   schemas are at: json/19115/-4/mdj/1.0.0/

TOOLS_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_DIR="$TOOLS_DIR/../mdj/1.0.0"
REPO_ROOT="$TOOLS_DIR/../../../.."

ajv validate \
  -d "$MODULE_DIR/examples/C1-19115-4-JSON-example.json" \
  -s "$MODULE_DIR/19115-4.json" \
  --spec=draft2020 \
  --validateFormats=true \
  --strict=false \
  -c ajv-formats \
  -r "$MODULE_DIR/mdj.json" \
  -r "$REPO_ROOT/json/19157/-1/dqc/1.0.0/dqc.json" \
  -r "$MODULE_DIR/Feature.json"
