#!/usr/bin/env bash
# Day 1 repeatable local tests for hello-v1.
# Usage:  ./tests/local-smoke.sh                 (defaults to the emulator on localhost:8998)
#         BASE_URL=http://localhost:8998 ./tests/local-smoke.sh
# Exit code: 0 = all passed, 1 = at least one failure (so CI can use it later).

BASE_URL="${BASE_URL:-http://localhost:8998}"
PASS=0
FAIL=0

run_test() {
  local name="$1" method="$2" path="$3" expected_status="$4" expected_body="$5"
  local body status
  local extra=()
  # POST/PUT without a body has no Content-Length, which Apigee rejects with 411.
  # Send an empty body so the request reaches the proxy.
  [[ "$method" != "GET" ]] && extra=(--data "")
  body=$(curl -s -X "$method" "${extra[@]}" -w $'\n%{http_code}' "${BASE_URL}${path}")
  status="${body##*$'\n'}"
  body="${body%$'\n'*}"

  if [[ "$status" == "$expected_status" && "$body" == *"$expected_body"* ]]; then
    echo "PASS  $name  ($status)"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $name"
    echo "      expected: $expected_status, body containing: $expected_body"
    echo "      got:      $status, body: $body"
    FAIL=$((FAIL + 1))
  fi
}

echo "Testing $BASE_URL"
run_test "happy path"            GET  "/v1/hello?name=Asmaa"     200 '"message":"Hello, Asmaa!"'
run_test "missing name -> World" GET  "/v1/hello"                200 '"message":"Hello, World!"'
run_test "invalid name (digits)" GET  "/v1/hello?name=Asmaa123"  400 '"error":"invalid_request"'
run_test "empty name"            GET  "/v1/hello?name="          400 '"error":"invalid_request"'
run_test "wrong method"          POST "/v1/hello"                404 '"error":"not_found"'
run_test "unknown sub-path"      GET  "/v1/hello/extra"          404 '"error":"not_found"'

echo "----"
echo "Passed: $PASS  Failed: $FAIL"
[[ $FAIL -eq 0 ]]
