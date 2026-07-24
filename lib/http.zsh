# lib/http.zsh - HTTP-Aufrufe gegen die REST-API & Zeitraum-Query-Parameter.
#
# Wird von `tt` gesourct; nicht direkt ausführbar.

# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------
# request METHOD PATH [curl-args...]   -> gibt Body auf stdout, Statuscode via Rückgabewert
typeset -g LAST_BODY=""
request() {
  local method=$1 endpoint=$2; shift 2
  local url="${TT_HOST%/}/api${endpoint}"
  local resp code curl_rc attempt
  for attempt in 1 2; do
    local auth_args=()
    if [[ $TT_AUTH == password ]]; then
      ensure_bearer || return 1
      auth_args=(-H "Authorization: Bearer ${TT_BEARER}")
    else
      auth_args=(-u "${TT_USER}:${TT_TOKEN}")
    fi
    resp=$(curl -sS -X "$method" \
        "${auth_args[@]}" \
        -H 'Accept: application/json' \
        -H 'Content-Type: application/json' \
        -w $'\n%{http_code}' \
        "$@" \
        "$url" 2>&1)
    curl_rc=$?
    if (( curl_rc != 0 )); then
      warn "Netzwerkfehler ($curl_rc) bei $method $url"
      print -u2 -- "$resp"
      return 1
    fi
    code=${resp##*$'\n'}
    LAST_BODY=${resp%$'\n'*}
    # Abgelaufener/ungültiger JWT: Cache verwerfen und einmal neu anmelden
    if [[ $code == 401 && $TT_AUTH == password && $attempt == 1 ]]; then
      rm -f "$TOKEN_CACHE"; TT_BEARER=""
      continue
    fi
    break
  done
  if [[ ! $code == 2* ]]; then
    warn "HTTP $code bei $method $endpoint"
    if print -r -- "$LAST_BODY" | jq -e . >/dev/null 2>&1; then
      print -r -- "$LAST_BODY" | jq . >&2
    else
      print -u2 -- "$LAST_BODY"
    fi
    return 1
  fi
  print -r -- "$LAST_BODY"
}

# ---------------------------------------------------------------------------
# Query-Parameter für einen Zeitraum aufbauen (in globales Array PARAMS)
# ---------------------------------------------------------------------------
typeset -ga PARAMS
build_range_params() {
  local from=$1 to=$2 by_booking=$3
  PARAMS=(-G)
  local acc=${OPT_ACCOUNT:-$TT_ACCOUNT_ID}
  [[ -n $acc ]] && PARAMS+=(--data-urlencode "accountId=$acc")
  [[ -z $from && -z $to ]] && return 0
  local off=$(local_offset)
  if (( by_booking )); then
    [[ -n $from ]] && PARAMS+=(--data-urlencode "fromDate=${from}T00:00:00${off}")
    [[ -n $to   ]] && PARAMS+=(--data-urlencode "toDate=${to}T23:59:59${off}")
  else
    [[ -n $from ]] && PARAMS+=(--data-urlencode "fromBalanceDate=${from}")
    [[ -n $to   ]] && PARAMS+=(--data-urlencode "toBalanceDate=${to}")
  fi
}

# ---------------------------------------------------------------------------
# Urlaub (Abwesenheiten) im Zeitraum abrufen
# ---------------------------------------------------------------------------
# fetch_vacation FROM TO  -> gibt auf stdout ein JSON-Array bestätigter Urlaubstage
# (exceptionType.internalName == "VACATION", approvalState == "APPROVED") aus.
# Schlägt der Abruf fehl, wird gewarnt und "[]" ausgegeben (Stunden bleiben nutzbar).
fetch_vacation() {
  local from=$1 to=$2
  local acc=${OPT_ACCOUNT:-$TT_ACCOUNT_ID}
  # Eigener User: .../slimmed/my ; für fremde Konten (-a): .../slimmed?accountId=...
  local endpoint="/working_time_exceptions/slimmed/my"
  local params=(-G --data-urlencode "source=ABSENCE_CALENDAR"
                --data-urlencode "fromDate=${from}" --data-urlencode "toDate=${to}")
  if [[ -n $acc ]]; then
    endpoint="/working_time_exceptions/slimmed"
    params+=(--data-urlencode "accountId=${acc}")
  fi
  local resp
  if ! resp=$(request GET "$endpoint" "${params[@]}"); then
    warn "Urlaub konnte nicht geladen werden - Stunden ohne Urlaub berechnet (--no-vacation unterdrückt diese Warnung)."
    print -- "[]"; return 0
  fi
  print -r -- "$resp" | jq -c '
    [ .[] | select((.exceptionType.internalName == "VACATION")
                   and (.approvalState == "APPROVED")) ]' 2>/dev/null \
    || print -- "[]"
}
