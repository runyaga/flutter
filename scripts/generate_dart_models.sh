#!/bin/bash
# scripts/generate_dart_models.sh
# Generate Dart models from JSON schemas for type-safe contract testing.

set -e

SCHEMA_DIR="../soliplex/schemas"
OUTPUT_DIR="packages/soliplex_client/lib/src/generated"

# Ensure schema directory exists
if [ ! -d "$SCHEMA_DIR" ]; then
    echo "Error: Schema directory not found at $SCHEMA_DIR"
    echo "Please run 'python scripts/generate_schemas.py' in the soliplex backend first."
    exit 1
fi

# Ensure quicktype is installed
if ! command -v quicktype &> /dev/null; then
    echo "quicktype not found. Installing..."
    npm install -g quicktype
fi

mkdir -p "$OUTPUT_DIR"

# List of schemas to generate (only those from our Pydantic models)
SCHEMAS=(
    "approval_request"
    "mission_artifact"
    "mission_state"
    "mission_summary"
    "task_item"
    "task_list"
    "state_delta_event"
)

# Generate Dart models from each schema
for name in "${SCHEMAS[@]}"; do
    schema="$SCHEMA_DIR/${name}.json"
    if [ -f "$schema" ]; then
        echo "Generating $name.dart..."
        quicktype \
            --src "$schema" \
            --src-lang schema \
            --lang dart \
            --out "$OUTPUT_DIR/${name}.dart" \
            --part-name "${name}" \
            --required-props \
            --null-safety
    else
        echo "Warning: Schema not found: $schema"
    fi
done

echo "Generated Dart models in $OUTPUT_DIR"
