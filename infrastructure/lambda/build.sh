#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT/api"
npm ci
npm run zip
echo "Built: $ROOT/api/function.zip"
echo "Update Lambda with:"
echo "  aws lambda update-function-code --function-name <NAME> --zip-file fileb://$ROOT/api/function.zip"
