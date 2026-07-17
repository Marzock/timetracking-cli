# lib/commands.zsh - Sub-Kommandos (login/config/current/range/hours) & Hilfetext.
#
# Wird von `tt` gesourct; nicht direkt ausführbar.

# ---------------------------------------------------------------------------
# Sub-Kommandos
# ---------------------------------------------------------------------------
cmd_login() {
  load_config
  local host user secret method acct_label
  print -n "Host (z.B. subdomain.timetracking-online.com)${TT_HOST:+ [$TT_HOST]}: "
  read host; host=${host:-$TT_HOST}
  host=${host#https://}; host=${host#http://}; host=${host%%/*}
  [[ -n $host ]] || die "Host darf nicht leer sein."

  print -n "Benutzername${TT_USER:+ [$TT_USER]}: "
  read user; user=${user:-$TT_USER}
  [[ -n $user ]] || die "Benutzername darf nicht leer sein."

  print "Anmeldeverfahren:"
  print "  [1] Benutzername + Passwort  (kein App-Token nötig)"
  print "  [2] App-Token"
  print -n "Auswahl [1]: "
  local choice; read choice; choice=${choice:-1}
  case $choice in
    2) method=apptoken; print -n "App-Token (Eingabe versteckt): " ;;
    *) method=password; print -n "Passwort (Eingabe versteckt): " ;;
  esac
  read -s secret; print ""
  [[ -n $secret ]] || die "Eingabe darf nicht leer sein."

  # Konfig schreiben
  mkdir -p "${TT_CONFIG:h}"
  {
    print -- "TT_HOST=\"https://${host}\""
    print -- "TT_USER=\"${user}\""
    print -- "TT_AUTH=\"${method}\""
    [[ -n ${TT_ACCOUNT_ID:-} ]] && print -- "TT_ACCOUNT_ID=\"${TT_ACCOUNT_ID}\""
    [[ -n ${TT_FROM:-} ]] && print -- "TT_FROM=\"${TT_FROM}\""
    [[ -n ${TT_TO:-} ]]   && print -- "TT_TO=\"${TT_TO}\""
  } > "$TT_CONFIG"
  chmod 600 "$TT_CONFIG"

  # Geheimnis im Schlüsselbund ablegen
  acct_label="${user}@https://${host}"
  security add-generic-password -U -s "$KEYCHAIN_SERVICE" -a "$acct_label" -w "$secret" \
    || die "Zugangsdaten konnten nicht im Schlüsselbund gespeichert werden."

  # Verbindung testen
  TT_HOST="https://${host}"; TT_USER="$user"; TT_TOKEN="$secret"; TT_AUTH="$method"; TT_BEARER=""
  rm -f "$TOKEN_CACHE"
  print "Teste Verbindung ..."
  if request GET "/working_time/entries/current" >/dev/null; then
    print "✓ Login erfolgreich. Konfiguration gespeichert unter $TT_CONFIG"
  else
    warn "Anmeldung gespeichert, aber Testabruf schlug fehl. Prüfe Zugangsdaten/Berechtigungen."
    return 1
  fi
}

cmd_config() {
  load_config
  print "Konfigurationsdatei: $TT_CONFIG"
  print "  TT_HOST       = ${TT_HOST:-<leer>}"
  print "  TT_USER       = ${TT_USER:-<leer>}"
  print "  TT_AUTH       = ${TT_AUTH:-apptoken}"
  print "  TT_ACCOUNT_ID = ${TT_ACCOUNT_ID:-<leer>}"
  print "  TT_FROM       = ${TT_FROM:-<leer>}"
  print "  TT_TO         = ${TT_TO:-<leer>}"
  local label="App-Token"; [[ ${TT_AUTH:-} == password ]] && label="Passwort"
  if load_credential; then
    print "  ${label} = ${TT_TOKEN:0:4}… (im Schlüsselbund)"
  else
    print "  ${label} = <nicht gefunden>"
  fi
}

cmd_range() {
  load_config
  case ${1:-} in
    ""|show|list)
      if [[ -n ${TT_FROM:-} || -n ${TT_TO:-} ]]; then
        print "Gespeicherter Zeitraum (wird von '${PROG} hours' automatisch genutzt):"
        print "  from = ${TT_FROM:-<leer - Standard>}"
        print "  to   = ${TT_TO:-<leer - Standard>}"
      else
        print "Kein Zeitraum gespeichert - es gilt der Standard (20.–19.):"
        print "  from = $(default_from)"
        print "  to   = $(default_to)"
      fi
      ;;
    clear|reset)
      config_unset TT_FROM
      config_unset TT_TO
      print "✓ Gespeicherter Zeitraum gelöscht - es gilt wieder der Standard (20.–19.)."
      ;;
    *)
      # Erlaubt:  range FROM TO   |   range --from D [--to D]   |   range --to D
      local from="" to=""
      while (( $# )); do
        case $1 in
          --from|-f) from=$(norm_date "$2"); shift 2 ;;
          --to|-t)   to=$(norm_date "$2"); shift 2 ;;
          -*) die "range: unbekannte Option '$1'" ;;
          *) if [[ -z $from ]]; then from=$(norm_date "$1")
             elif [[ -z $to ]]; then to=$(norm_date "$1")
             else die "range: zu viele Argumente (erwartet: FROM [TO])"; fi
             shift ;;
        esac
      done
      [[ -z $from && -z $to ]] && die "range: kein Datum angegeben. Beispiel: ${PROG} range 20.07.26 19.08.26"
      [[ -n $from ]] && config_set TT_FROM "$from"
      [[ -n $to ]]   && config_set TT_TO "$to"
      load_config
      print "✓ Zeitraum gespeichert:"
      print "  from = ${TT_FROM:-<leer>}"
      print "  to   = ${TT_TO:-<leer>}"
      ;;
  esac
}

cmd_current() {
  ensure_auth
  local out
  out=$(request GET "/working_time/entries/current") || return 1
  if (( OPT_JSON )); then print -r -- "$out"; return; fi
  print -r -- "$out" | jq -r "$JQ_LIB"'
    "Account:        \(.account.id // .account // "?")",
    "Status:         \(.approvalState // "-")",
    "Beginn:         \(.beginningDate // "-")",
    "Ende:           \(.endingDate // "- (läuft)")",
    "Erste Buchung:  \(.firstBookingType // "-")",
    "Letzte Buchung: \(.lastBookingType // "-")",
    (if .allowedBookings then "Mögliche Buchungen: " + ([.allowedBookings[] | "\(.type)/\(.direction)"] | join(", ")) else empty end)
  '
}

cmd_hours() {
  local from="" to="" by_booking=0
  while (( $# )); do
    case $1 in
      --from|-f) from=$(norm_date "$2"); shift 2 ;;
      --to|-t)   to=$(norm_date "$2"); shift 2 ;;
      --by-booking) by_booking=1; shift ;;
      *) die "hours: unbekannte Option '$1'" ;;
    esac
  done
  ensure_auth   # lädt u.a. gespeicherte TT_FROM/TT_TO aus der Konfiguration
  # Vorrang: --from/--to (pro Aufruf) > gespeichert (TT_FROM/TT_TO) > Standard (20.–19.)
  [[ -n $from ]] || from=${TT_FROM:-}
  [[ -n $to ]]   || to=${TT_TO:-}
  [[ -n $from ]] || from=$(default_from)
  [[ -n $to ]]   || to=$(default_to)
  build_range_params "$from" "$to" "$by_booking"
  local out
  out=$(request GET "/working_time/entries" "${PARAMS[@]}") || return 1
  if (( OPT_JSON )); then print -r -- "$out"; return; fi

  local from_disp=$(date -j -f "%Y-%m-%d" "$from" "+%d.%m.%y" 2>/dev/null || print -- "$from")
  local to_disp=$(date -j -f "%Y-%m-%d" "$to" "+%d.%m.%y" 2>/dev/null || print -- "$to")

  print -r -- "$out" | jq -r "$JQ_LIB"'
    real_entries as $e
    | ($e | map(dur_secs) | add // 0) as $total
    | ($e | group_by(.balanceDay // (.beginningDate[0:10]))
          | map({day: (.[0].balanceDay // (.[0].beginningDate[0:10])),
                 secs: (map(dur_secs) | add // 0)})
          | sort_by(.day)) as $days
    | ($days | group_by(.day | week_monday) | sort_by(.[0].day)) as $weeks
    | "Zeitraum:      '"$from_disp"'  bis  '"$to_disp"'",
      "Einträge:      \($e | length)   an \($days | length) Tag(en)",
      "",
      "Tag                Stunden",
      ($weeks[]
        | ((map(.secs) | add) // 0) as $wsecs
        | (
            (.[] | "\(.day | wday_de) \(.day | ddmmyy)      \(.secs | hhmm)   (\((.secs/3600*100|round)/100) h)"),
            "─────────────────────────────────",
            "                \($wsecs | hhmm)   (\((($wsecs/3600)*100|round)/100) h)",
            ""
          )
      ),
      "═════════════════════════════════",
      "Summe:         \($total | hhmm)   =  \((($total/3600)*100|round)/100) Stunden"
  '
}

usage() {
  cat <<EOF
${PROG} - CLI für TimeTracking Online

AUFRUF
  ${PROG} [-j] [-a ACCOUNT_ID] <befehl> [optionen]

GLOBALE OPTIONEN
  -j, --json           Rohes JSON ausgeben (statt Tabelle)
  -a, --account ID     accountId für Admin-Abfragen fremder Konten
  -h, --help           Diese Hilfe

BEFEHLE
  login                Zugang einrichten: Passwort ODER App-Token (-> Schlüsselbund)
  config               Aktuelle Konfiguration anzeigen
  current              Aktuelle Arbeitszeit / Status (zeigt auch die eigene Account-ID)

  range [FROM [TO]]    Standard-Zeitraum für 'hours' anzeigen/speichern
    range                    aktuell gespeicherten Zeitraum anzeigen
    range 20.07.26 19.08.26  from und to speichern
    range --from 20.07.26    nur from speichern (--to analog)
    range clear              gespeicherten Zeitraum löschen (zurück zum Standard)

  hours    [--from D] [--to D] [--by-booking]
                       Geleistete Stunden im Zeitraum summieren (+ Tagesaufstellung)
                       Zeitraum-Vorrang: --from/--to  >  gespeichert (range)  >  Standard (20.–19.)

DATUMSFORMATE
  20.05.26   20.05.2026   2026-05-20   today

BEISPIELE
  ${PROG} login
  ${PROG} current
  ${PROG} range 20.07.26 19.08.26     # Zeitraum einmalig festlegen
  ${PROG} hours                       # nutzt den gespeicherten Zeitraum
  ${PROG} hours --from 20.05.26 --to 19.06.26   # überschreibt nur diesen Aufruf

Standardmäßig filtert der Zeitraum nach Buchungstag (balanceDay). Mit --by-booking
wird stattdessen nach dem tatsächlichen Buchungszeitstempel gefiltert.
EOF
}
