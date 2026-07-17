# lib/jqlib.zsh - Gemeinsame jq-Bausteine (in globaler Variable JQ_LIB).
#
# Wird von `tt` gesourct; nicht direkt ausführbar.

# ---------------------------------------------------------------------------
# Gemeinsame jq-Bausteine
# ---------------------------------------------------------------------------
# Wandelt ISO-8601-Zeitstempel mit Offset (…+02:00 oder …Z) in Unix-Epoch.
read -r -d '' JQ_LIB <<'JQEOF' || true
def iso2epoch:
  if . == null or . == "" then null
  else
    (.[0:19] | strptime("%Y-%m-%dT%H:%M:%S") | mktime) as $utc
    | .[19:] as $off
    | (if ($off == "Z" or $off == "") then 0
       else ((($off[1:3]|tonumber)*3600) + (($off[4:6]|tonumber)*60))
            * (if $off[0:1] == "-" then -1 else 1 end)
       end) as $os
    | $utc - $os
  end;
# Dauer eines Eintrags in Sekunden (0 wenn offen/ungültig)
def dur_secs:
  (.beginningDate | iso2epoch) as $b
  | (.endingDate | iso2epoch) as $e
  | if $b == null or $e == null then 0 else ($e - $b) end;
# Sekunden -> "H:MM"
def hhmm: (. as $s | ($s/3600|floor) as $h | (($s%3600)/60|floor) as $m
           | "\($h):\(if $m < 10 then "0" else "" end)\($m)");
# nur reale Einträge (keine gelöschten/stornierten)
def real_entries: map(select((.approvalState // "") | . != "DELETED" and . != "CANCELLED"));
def hm: (.[11:16] // "");
# yyyy-mm-dd -> deutscher Wochentag (Mo..So)
def wday_de:
  if . == null or . == "" then ""
  else (.[0:10] | strptime("%Y-%m-%d") | mktime | gmtime | .[6]) as $w
       | ["So","Mo","Di","Mi","Do","Fr","Sa"][$w] end;
# yyyy-mm-dd -> dd.mm.yy
def ddmmyy:
  if . == null or . == "" then ""
  else .[0:10] | (.[8:10] + "." + .[5:7] + "." + .[2:4]) end;
# yyyy-mm-dd -> Montag (yyyy-mm-dd) der zugehörigen Kalenderwoche
def week_monday:
  if . == null or . == "" then ""
  else (.[0:10] | strptime("%Y-%m-%d") | mktime) as $t
       | ($t | gmtime | .[6]) as $w
       | ((($w + 6) % 7) * 86400) as $back
       | (($t - $back) | gmtime | strftime("%Y-%m-%d")) end;
JQEOF
