# lib/config.zsh - Konfigurationsdatei & Zugangsdaten (Schlüsselbund).
#
# Wird von `tt` gesourct; nicht direkt ausführbar.

load_config() {
  [[ -f $TT_CONFIG ]] && source "$TT_CONFIG"
  : ${TT_HOST:=""} ${TT_USER:=""} ${TT_ACCOUNT_ID:=""} ${TT_AUTH:="apptoken"} \
    ${TT_FROM:=""} ${TT_TO:=""}
}

# Einen Schlüssel in der Konfigdatei setzen/aktualisieren; andere Zeilen bleiben erhalten.
config_set() {
  local key=$1 val=$2 tmp
  mkdir -p "${TT_CONFIG:h}"
  tmp=$(mktemp "${TT_CONFIG}.XXXXXX") || die "Temporäre Datei konnte nicht angelegt werden."
  [[ -f $TT_CONFIG ]] && grep -v "^${key}=" "$TT_CONFIG" > "$tmp"
  print -- "${key}=\"${val}\"" >> "$tmp"
  mv "$tmp" "$TT_CONFIG"
  chmod 600 "$TT_CONFIG"
}

# Einen Schlüssel aus der Konfigdatei entfernen.
config_unset() {
  local key=$1 tmp
  [[ -f $TT_CONFIG ]] || return 0
  tmp=$(mktemp "${TT_CONFIG}.XXXXXX") || die "Temporäre Datei konnte nicht angelegt werden."
  grep -v "^${key}=" "$TT_CONFIG" > "$tmp"
  mv "$tmp" "$TT_CONFIG"
  chmod 600 "$TT_CONFIG"
}

# Geheimnis (App-Token bzw. Passwort) aus Umgebung oder Schlüsselbund holen -> TT_TOKEN
load_credential() {
  [[ -n ${TT_TOKEN:-} ]] && return 0
  [[ -n $TT_USER && -n $TT_HOST ]] || return 1
  TT_TOKEN=$(security find-generic-password \
      -s "$KEYCHAIN_SERVICE" -a "${TT_USER}@${TT_HOST}" -w 2>/dev/null) || return 1
  [[ -n $TT_TOKEN ]]
}

ensure_auth() {
  load_config
  [[ -n $TT_HOST ]] || die "Kein Host konfiguriert. Führe zuerst '${PROG} login' aus."
  [[ -n $TT_USER ]] || die "Kein Benutzer konfiguriert. Führe zuerst '${PROG} login' aus."
  if [[ $TT_AUTH == password ]]; then
    load_credential || die "Kein Passwort hinterlegt. Führe '${PROG} login' aus oder setze \$TT_TOKEN."
  else
    load_credential || die "Kein App-Token gefunden. Führe '${PROG} login' aus oder setze \$TT_TOKEN."
  fi
}
