#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$ROOT/ca" "$ROOT/mqtt" "$ROOT/clients/headunit"
# CA
openssl req -x509 -new -nodes -days 3650 -newkey rsa:4096 \
  -subj "/CN=CDR-Local-CA" \
  -keyout "$ROOT/ca/ca.key" -out "$ROOT/ca/ca.crt"
# Server
openssl req -new -nodes -newkey rsa:4096 \
  -subj "/CN=headunit.local" \
  -keyout "$ROOT/mqtt/server.key" -out "$ROOT/mqtt/server.csr"
openssl x509 -req -in "$ROOT/mqtt/server.csr" -CA "$ROOT/ca/ca.crt" -CAkey "$ROOT/ca/ca.key" \
  -CAcreateserial -out "$ROOT/mqtt/server.crt" -days 825 -sha256
openssl dhparam -out "$ROOT/mqtt/dhparam.pem" 2048
# Client (headunit)
openssl req -new -nodes -newkey rsa:4096 \
  -subj "/CN=headunit" \
  -keyout "$ROOT/clients/headunit/client.key" -out "$ROOT/clients/headunit/client.csr"
openssl x509 -req -in "$ROOT/clients/headunit/client.csr" \
  -CA "$ROOT/ca/ca.crt" -CAkey "$ROOT/ca/ca.key" -CAcreateserial \
  -out "$ROOT/clients/headunit/client.crt" -days 825 -sha256
echo "Done."
