# tt - CLI für TimeTracking Online

Kommandozeilen-Tool für die REST-API von [TimeTracking Online](https://timetracking-online.com)
(Herrmann & Lenz Solutions). Fragt Arbeitszeiten ab, summiert geleistete Stunden
in einem Zeitraum und exportiert Daten.

- API-Doku: <https://demo.timetracking-online.com/api/docs/index.html>

## Voraussetzungen

- `curl` und `jq` (auf macOS via `brew install jq`)
- Zugangsdaten – **eine** der beiden Varianten:
  1. **Benutzername + Passwort** (deine normalen Login-Daten). Es wird per
     `POST /api/auth/authorize` ein kurzlebiger JWT-Token geholt und
     zwischengespeichert – kein App-Token nötig.
  2. **App-Token** (Format `app_` + 64 Zeichen). In der Web-App unter den
     Benutzer-/Profileinstellungen („App-Tokens" / API-Zugang) erzeugen –
     nur möglich, wenn man die Berechtigung dazu hat.

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
| `tt current` | Aktueller Status / laufende Arbeitszeit (zeigt auch die eigene Account-ID) |
| `tt hours --from D --to D` | Geleistete Stunden summieren (+ Tagesaufstellung) |
| `tt config` | Konfiguration anzeigen |

Globale Flags: `-j/--json` (rohes JSON), `-a/--account ID` (fremdes Konto, Admin).

Datumsformate: `20.05.26`, `20.05.2026`, `2026-05-20`, `today`.

## Beispiele

```sh
# Geleistete Stunden im Abrechnungszeitraum
tt hours --from 20.05.26 --to 19.06.26

```