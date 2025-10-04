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
{"iss":"${ISSUER}","aud":"${AUD}","sub":"urn:lims:user:admin","preferred_username":"admin","email":"admin@example.org","roles":["app_admin","app_operator"],"exp":${EXP},"iat":1700000000}
JSON
)

operator_payload=$(cat <<JSON
{"iss":"${ISSUER}","aud":"${AUD}","sub":"urn:lims:user:operator","preferred_username":"operator","email":"operator@example.org","roles":["app_operator"],"exp":${EXP},"iat":1700000000}
JSON
)

researcher_payload=$(cat <<JSON
{"iss":"${ISSUER}","aud":"${AUD}","sub":"urn:lims:user:alice","preferred_username":"alice","email":"alice@example.org","roles":["app_researcher"],"exp":${EXP},"iat":1700000000}
JSON
)

emit_token "admin" "${admin_payload}"
emit_token "operator" "${operator_payload}"
emit_token "researcher" "${researcher_payload}"
