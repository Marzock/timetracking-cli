# lib/auth.zsh - Passwort-Anmeldung (grant_type=password) & Bearer-Token-Cache.
#
# Wird von `tt` gesourct; nicht direkt ausführbar.

# JWT-Access-Token per Benutzername/Passwort holen (grant_type=password) -> TT_BEARER
authorize() {
  local body resp code
  body=$(jq -n --arg u "$TT_USER" --arg p "$TT_TOKEN" \
         '{grant_type:"password", username:$u, password:$p}')
  resp=$(curl -sS -X POST "${TT_HOST%/}/api/auth/authorize" \
      -H 'Content-Type: application/json' -H 'Accept: application/json' \
      --data-binary "$body" -w $'\n%{http_code}' 2>&1)
  if (( $? != 0 )); then warn "Netzwerkfehler bei der Anmeldung"; print -u2 -- "$resp"; return 1; fi
  code=${resp##*$'\n'}
  local jbody=${resp%$'\n'*}
  if [[ ! $code == 2* ]]; then
    warn "Anmeldung fehlgeschlagen (HTTP $code)"
    print -u2 -- "$jbody"
    return 1
  fi
  TT_BEARER=$(print -r -- "$jbody" | jq -r '.access_token // empty')
  [[ -n $TT_BEARER ]] || { warn "Kein access_token in der Antwort"; return 1; }
  # Ablaufzeitpunkt (mit 30s Puffer) berechnen und Token cachen
  local expires_in exp_epoch
  expires_in=$(print -r -- "$jbody" | jq -r '.expires_in // 300')
  exp_epoch=$(( $(date +%s) + expires_in - 30 ))
  mkdir -p "${TOKEN_CACHE:h}"
  print -r -- "$TT_BEARER"$'\n'"$exp_epoch" > "$TOKEN_CACHE"
  chmod 600 "$TOKEN_CACHE"
}

# Gültigen Bearer-Token sicherstellen (aus Cache oder frisch anfordern)
ensure_bearer() {
  [[ -n $TT_BEARER ]] && return 0
  if [[ -f $TOKEN_CACHE ]]; then
    local content=$(<"$TOKEN_CACHE")
    local tok=${content%%$'\n'*} exp=${content##*$'\n'}
    if [[ -n $tok && -n $exp ]] && (( exp > $(date +%s) )); then
      TT_BEARER=$tok; return 0
    fi
  fi
  authorize
}
