#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRET="${PGRST_JWT_SECRET:-dev_jwt_secret_change_me_which_is_at_least_32_characters}"
EXP=4070908800
ISSUER="dev-issuer"
AUD="lims-dev"

base64url_encode() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

sign_token() {
  local signing_input="$1"
  printf '%s' "${signing_input}" | openssl dgst -binary -sha256 -hmac "${SECRET}" | base64url_encode
}

emit_token() {
  local name="$1"
  local payload="$2"

  local header_b64 payload_b64 signature token_path
  header_b64="$(printf '%s' '{"alg":"HS256","typ":"JWT"}' | base64url_encode)"
  payload_b64="$(printf '%s' "${payload}" | base64url_encode)"
  signature="$(sign_token "${header_b64}.${payload_b64}")"
  token_path="${SCRIPT_DIR}/${name}.jwt"

  printf '%s.%s.%s\n' "${header_b64}" "${payload_b64}" "${signature}" > "${token_path}"
  printf 'Wrote %s\n' "${token_path}" >&2
}

admin_payload=$(cat <<JSON
{"iss":"${ISSUER}","aud":"${AUD}","sub":"urn:app:admin","preferred_username":"admin","email":"admin@example.org","roles":["app_admin","app_operator"],"role":"app_admin","exp":${EXP},"iat":1700000000}
JSON
)

operator_payload=$(cat <<JSON
{"iss":"${ISSUER}","aud":"${AUD}","sub":"urn:app:ops","preferred_username":"ops","email":"ops@example.org","roles":["app_operator"],"role":"app_operator","exp":${EXP},"iat":1700000000}
JSON
)

researcher_payload=$(cat <<JSON
{"iss":"${ISSUER}","aud":"${AUD}","sub":"urn:app:alice","preferred_username":"alice","email":"alice@example.org","roles":["app_researcher"],"role":"app_researcher","exp":${EXP},"iat":1700000000}
JSON
)

external_payload=$(cat <<JSON
{"iss":"${ISSUER}","aud":"${AUD}","sub":"urn:app:external","preferred_username":"external","email":"external@example.org","roles":["app_external"],"role":"app_external","exp":${EXP},"iat":1700000000}
JSON
)

automation_payload=$(cat <<JSON
{"iss":"${ISSUER}","aud":"${AUD}","sub":"urn:app:automation","preferred_username":"automation","email":"automation@example.org","roles":["app_automation"],"role":"app_automation","exp":${EXP},"iat":1700000000}
JSON
)

emit_token "admin" "${admin_payload}"
emit_token "operator" "${operator_payload}"
emit_token "researcher" "${researcher_payload}"
emit_token "external" "${external_payload}"
emit_token "automation" "${automation_payload}"
