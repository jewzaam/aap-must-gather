#!/bin/bash
set -euo pipefail

CLUSTER_NAME="aap-must-gather-e2e"
IMAGE="${IMAGE:-localhost/aap-must-gather:e2e}"
IMAGE_TAR="aap-must-gather.tar"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FAILURES=0

cleanup() {
  echo "Deleting kind cluster $CLUSTER_NAME"
  kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
  rm -f "$IMAGE_TAR"
}
trap cleanup EXIT

assert_contains() {
  local file="$1" pattern="$2"
  if grep -q "$pattern" "$file"; then
    echo "  PASS: output contains '$pattern'"
  else
    echo "  FAIL: expected '$pattern' in output"
    FAILURES=$((FAILURES + 1))
  fi
}

assert_not_contains() {
  local file="$1" pattern="$2"
  if grep -q "$pattern" "$file"; then
    echo "  FAIL: unexpected '$pattern' in output"
    FAILURES=$((FAILURES + 1))
  else
    echo "  PASS: output does not contain '$pattern'"
  fi
}

echo "=== Building image ==="
podman build -f "$SCRIPT_DIR/Dockerfile" --tag "$IMAGE" "$SCRIPT_DIR"

echo "=== Creating kind cluster ==="
kind create cluster --name "$CLUSTER_NAME"

echo "=== Loading image into kind ==="
podman save "$IMAGE" -o "$IMAGE_TAR"
kind load image-archive "$IMAGE_TAR" --name "$CLUSTER_NAME"

echo "=== Running test scenarios ==="

run_scenario() {
  local label="$1"; shift
  echo "--- Scenario: $label ---" >&2
  rm -rf must-gather.local.*
  local outfile
  outfile=$(mktemp)
  oc adm must-gather --image="$IMAGE" -- "$@" &> "$outfile" || true
  printf '%s' "$outfile"
}

# All resources, all namespaces (default)
out=$(run_scenario "gather (all, all namespaces)" /usr/bin/gather)
assert_contains "$out" automationcontrollers
assert_contains "$out" automationorchestrators
assert_contains "$out" "across all namespaces"
rm -f "$out"

# AAP only, all namespaces
out=$(run_scenario "gather --aap-only" /usr/bin/gather --aap-only)
assert_contains "$out" automationcontrollers
assert_not_contains "$out" automationorchestrators
assert_contains "$out" "across all namespaces"
rm -f "$out"

# AO only, all namespaces
out=$(run_scenario "gather --ao-only" /usr/bin/gather --ao-only)
assert_contains "$out" automationorchestrators
assert_not_contains "$out" automationcontrollers
assert_contains "$out" "across all namespaces"
rm -f "$out"

# All resources, single namespace
out=$(run_scenario "gather -n default" /usr/bin/gather -n default)
assert_contains "$out" automationcontrollers
assert_contains "$out" automationorchestrators
assert_contains "$out" "in namespace default"
assert_not_contains "$out" "across all namespaces"
rm -f "$out"

# AAP only, single namespace
out=$(run_scenario "gather --aap-only -n default" /usr/bin/gather --aap-only -n default)
assert_contains "$out" automationcontrollers
assert_not_contains "$out" automationorchestrators
assert_contains "$out" "in namespace default"
assert_not_contains "$out" "across all namespaces"
rm -f "$out"

# AO only, single namespace
out=$(run_scenario "gather --ao-only -n default" /usr/bin/gather --ao-only -n default)
assert_contains "$out" automationorchestrators
assert_not_contains "$out" automationcontrollers
assert_contains "$out" "in namespace default"
assert_not_contains "$out" "across all namespaces"
rm -f "$out"

# --aap-only and --ao-only are mutually exclusive
out=$(run_scenario "gather --aap-only --ao-only (mutual exclusion)" /usr/bin/gather --aap-only --ao-only)
assert_contains "$out" "mutually exclusive"
rm -f "$out"

# Positional namespace arg (backward compat with ns-gather)
out=$(run_scenario "ns-gather <positional namespace>" /usr/bin/ns-gather default)
assert_contains "$out" "in namespace default"
assert_not_contains "$out" "across all namespaces"
rm -f "$out"

rm -rf must-gather.local.*

echo ""
if [[ "$FAILURES" -gt 0 ]]; then
  echo "=== $FAILURES assertion(s) FAILED ==="
  exit 1
else
  echo "=== All assertions passed ==="
fi
