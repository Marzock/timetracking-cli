# lib/util.zsh - Allgemeine Hilfsfunktionen (Fehlerausgabe, Datum, Zeitraum).
#
# Wird von `tt` gesourct; nicht direkt ausführbar.

# ---------------------------------------------------------------------------
# Fehler-/Statusausgabe
# ---------------------------------------------------------------------------
die() { print -u2 -- "${PROG}: $*"; exit 1; }
warn() { print -u2 -- "${PROG}: $*"; }

need() { command -v "$1" >/dev/null 2>&1 || die "'$1' wird benötigt, ist aber nicht installiert."; }

# ---------------------------------------------------------------------------
# Datum & Zeitraum
# ---------------------------------------------------------------------------
# Lokaler UTC-Offset im Format +02:00
local_offset() {
  local z=$(date +%z)          # z.B. +0200
  print -- "${z:0:3}:${z:3:2}"
}

# Datumseingabe normalisieren -> yyyy-mm-dd
# Akzeptiert: 20.05.26  20.05.2026  2026-05-20  "today" "heute"
norm_date() {
  local in=$1
  case $in in
    today|heute|now) date "+%Y-%m-%d"; return ;;
  esac
  local out
  for fmt in "%Y-%m-%d" "%d.%m.%Y" "%d.%m.%y" "%d.%m." "%d.%m"; do
    if out=$(date -j -f "$fmt" "$in" "+%Y-%m-%d" 2>/dev/null); then
      print -- "$out"; return 0
    fi
  done
  die "Datum '$in' nicht erkannt. Nutze z.B. 20.05.26 oder 2026-05-20."
}

# Standard-Abrechnungszeitraum (20. bis 19.):
# from = 20. des aktuellen Monats, wenn heute >= 20., sonst 20. des Vormonats.
# to   = 19. des aktuellen Monats, wenn heute <= 19., sonst 19. des Folgemonats.
default_from() {
  local day=$(date +%d)
  if (( 10#$day >= 20 )); then
    date -v20d "+%Y-%m-%d"
  else
    date -v20d -v-1m "+%Y-%m-%d"
  fi
}
default_to() {
  local day=$(date +%d)
  if (( 10#$day <= 19 )); then
    date -v19d "+%Y-%m-%d"
  else
    date -v19d -v+1m "+%Y-%m-%d"
  fi
}

# Buchungszeitstempel für heute erzeugen -> yyyy-mm-ddThh:mm:00±hh:mm
# Ohne Argument (bzw. leer): aktuelle Uhrzeit.
# Mit "hh:mm": heutiges Datum + angegebene Uhrzeit (Sekunden = 00).
booking_ts() {
  local t=${1:-} off
  off=$(local_offset)
  if [[ -z $t ]]; then
    date "+%Y-%m-%dT%H:%M:%S${off}"
    return 0
  fi
  local hh=${t%%:*} mm=${t#*:}
  [[ $t == *:* && $hh == <-> && $mm == <-> ]] \
    || die "Ungültige Zeit '$t'. Erwartet: hh:mm (z.B. 09:00)."
  (( 10#$hh <= 23 && 10#$mm <= 59 )) \
    || die "Ungültige Zeit '$t'. Stunden 00-23, Minuten 00-59."
  printf '%sT%02d:%02d:00%s\n' "$(date +%Y-%m-%d)" "$((10#$hh))" "$((10#$mm))" "$off"
}
