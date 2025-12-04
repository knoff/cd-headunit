# Headunit Core Stack (MQTT mTLS+ACL + Nginx TLS + MinIO)

## Run

```bash
cd deploy/compose/certs && ./mkcerts.sh
cd ..
cp .env.example .env && edit it
docker compose up -d
```

## Verify

- MinIO Console: `https://<PI_IP>/console`
- MQTT mTLS publish test:

```bash
mosquitto_pub -h <PI_IP> -p 8883 -t "telemetry/test" -m "hello" \
 --cafile certs/ca/ca.crt \
 --cert certs/clients/headunit/client.crt \
 --key certs/clients/headunit/client.key
```
