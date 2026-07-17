# tt - CLI für TimeTracking Online

Kommandozeilen-Tool für die REST-API von [TimeTracking Online](https://timetracking-online.com)
(Herrmann & Lenz Solutions). Zeigt die aktuelle Arbeitszeit an und summiert
geleistete Stunden in einem Zeitraum (mit Tages- und Wochenaufstellung).

- API-Doku: <https://demo.timetracking-online.com/api/docs/index.html>

## Voraussetzungen

- `curl` und `jq` (auf macOS via `brew install jq`)
- macOS (nutzt `security` für den Schlüsselbund und BSD-`date`)
- Zugangsdaten – **eine** der beiden Varianten:
  1. **Benutzername + Passwort** (deine normalen Login-Daten). Es wird per
     `POST /api/auth/authorize` ein kurzlebiger JWT-Token geholt und
     zwischengespeichert – kein App-Token nötig.
  2. **App-Token** (Format `app_` + 64 Zeichen). In der Web-App unter den
     Benutzer-/Profileinstellungen („App-Tokens" / API-Zugang) erzeugen –
     nur möglich, wenn man die Berechtigung dazu hat.

## Installation

Das Skript ist selbstständig lauffähig; es muss nur ausführbar und im `PATH`
sein. Am einfachsten per Symlink in ein `bin`-Verzeichnis:

```sh
git clone <repo-url> ~/Development/timetracking
chmod +x ~/Development/timetracking/tt
ln -s ~/Development/timetracking/tt ~/bin/tt   # ~/bin muss im PATH liegen
```

Liegt `~/bin` noch nicht im `PATH`, in der `~/.zshrc` ergänzen:

```sh
export PATH="$HOME/bin:$PATH"
```

Der Symlink wird beim Start aufgelöst, sodass `tt` seine `lib/*.zsh` auch dann
findet, wenn es aus einem anderen Verzeichnis heraus aufgerufen wird.

## Einrichtung

```sh
tt login
```

Fragt Host, Benutzername und das Anmeldeverfahren (Passwort **oder** App-Token)
ab. Host/User/Verfahren landen in `~/.config/timetracking/config`, das Geheimnis
sicher im macOS-Schlüsselbund (nicht im Klartext auf der Platte). Im
Passwort-Modus werden JWT-Tokens in `~/.config/timetracking/token-cache`
zwischengespeichert und bei Ablauf automatisch erneuert. Am Ende wird die
Verbindung getestet.

Alternativ ohne `login` per Umgebungsvariablen: `TT_HOST`, `TT_USER`, `TT_TOKEN`
(App-Token oder Passwort) und `TT_AUTH` (`apptoken` oder `password`).

## Befehle

| Befehl | Zweck |
|--------|-------|
| `tt current` | Aktueller Status / laufende Arbeitszeit (zeigt auch die eigene Account-ID). Aliase: `status`, `whoami` |
| `tt hours --from D --to D` | Geleistete Stunden summieren (+ Tages- und Wochenaufstellung). Alias: `stunden` |
| `tt range [FROM [TO]]` | Standard-Zeitraum für `hours` anzeigen/speichern/löschen. Alias: `zeitraum` |
| `tt config` | Konfiguration anzeigen |
| `tt login` | Zugang einrichten |
| `tt help` | Hilfe anzeigen |

Globale Flags: `-j/--json` (rohes JSON), `-a/--account ID` (fremdes Konto, Admin).

Datumsformate: `20.05.26`, `20.05.2026`, `2026-05-20`, `20.05.` und `today`
(bzw. `heute`, `now`).

### Zeitraum (`range`)

`hours` verwendet standardmäßig den Abrechnungszeitraum vom 20. bis zum 19. des
Folgemonats. Über `range` lässt sich ein anderer Zeitraum dauerhaft speichern:

```sh
tt range                       # gespeicherten Zeitraum (oder Standard) anzeigen
tt range 20.07.26 19.08.26     # from und to speichern
tt range --from 20.07.26       # nur from speichern (--to analog)
tt range clear                 # gespeicherten Zeitraum löschen (zurück zum Standard)
```

Zeitraum-Vorrang bei `hours`: `--from`/`--to` (pro Aufruf) > gespeichert (`range`)
> Standard (20.–19.).

### Stunden (`hours`)

```sh
tt hours                                     # gespeicherter Zeitraum oder Standard
tt hours --from 20.05.26 --to 19.06.26       # überschreibt nur diesen Aufruf
tt hours --by-booking                        # nach Buchungszeitstempel filtern
```

Standardmäßig filtert `hours` nach Buchungstag (`balanceDay`). Mit `--by-booking`
wird stattdessen nach dem tatsächlichen Buchungszeitstempel gefiltert.

## Konfiguration

Die Konfigdatei (`~/.config/timetracking/config`, `chmod 600`) enthält:

| Schlüssel | Bedeutung |
|-----------|-----------|
| `TT_HOST` | API-Host (`https://subdomain.timetracking-online.com`) |
| `TT_USER` | Benutzername |
| `TT_AUTH` | Anmeldeverfahren: `password` oder `apptoken` |
| `TT_ACCOUNT_ID` | Optional: Standard-Konto für Abfragen |
| `TT_FROM`, `TT_TO` | Optional: gespeicherter Zeitraum (via `range`) |

Das Geheimnis (Passwort bzw. App-Token) liegt nie in dieser Datei, sondern im
macOS-Schlüsselbund (Dienst `timetracking-online`).

## Beispiele

```sh
# Zeitraum einmalig festlegen ...
tt range 20.07.26 19.08.26

# ... und danach ohne Argumente abrufen
tt hours

# Geleistete Stunden in einem beliebigen Abrechnungszeitraum
tt hours --from 20.05.26 --to 19.06.26

# Rohes JSON für Weiterverarbeitung
tt -j hours --from 2026-05-20 --to 2026-06-19 | jq '.[].beginningDate'
```

## Aufbau

```
tt              Setup, Konstanten, Argument-Parsing; sourct lib/*.zsh
lib/util.zsh    Fehlerausgabe, Datum-/Zeitraum-Helfer
lib/config.zsh  Konfigdatei & Zugangsdaten (Schlüsselbund)
lib/auth.zsh    Passwort-Anmeldung & Bearer-Token-Cache
lib/http.zsh    HTTP-Requests & Zeitraum-Query-Parameter
lib/jqlib.zsh   Gemeinsame jq-Bausteine (JQ_LIB)
lib/commands.zsh Sub-Kommandos & Hilfetext
```
