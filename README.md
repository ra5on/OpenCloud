# OpenCloud ARM64 – Installations-Script

Automatisches Installations-Script für [OpenCloud](https://opencloud.eu) auf ARM64-Systemen (z.B. Raspberry Pi 5, Ampere, Apple Silicon Server). Richtet OpenCloud inkl. aller Web-Apps für den lokalen Netzwerkzugriff ein.

---

## Voraussetzungen

| Anforderung | Details |
|-------------|---------|
| **Betriebssystem** | Ubuntu 24.04 oder Debian 12 (ARM64 / aarch64) |
| **Architektur** | ARM64 (aarch64) |
| **RAM** | Mindestens 2 GB (empfohlen: 4 GB+) |
| **Speicher** | Mindestens 10 GB frei |
| **Netzwerk** | Internetzugang für Downloads |
| **Rechte** | root oder sudo |

---

## Schnellstart

```bash
# 1. Script herunterladen
wget https://raw.githubusercontent.com/ra5on/OpenCloud/refs/heads/main/opencloud-setup.sh

# 2. Passwort anpassen (wichtig!)
nano opencloud-setup.sh
# → ADMIN_PASSWORD="MeinSicheresPasswort!"

# 3. Ausführbar machen und starten
chmod +x opencloud-setup.sh
sudo ./opencloud-setup.sh
```

Nach der Installation ist OpenCloud erreichbar unter:
```
https://<IP-Adresse>:9200
```
Die IP wird automatisch ermittelt und am Ende ausgegeben.

> ⚠️ Das Zertifikat ist selbstsigniert. Die Browserwarnung einfach bestätigen und fortfahren.

---

## Konfiguration

Am Anfang des Scripts können folgende Werte angepasst werden:

```bash
ADMIN_PASSWORD="Admin1234!"   # Admin-Passwort – BITTE ÄNDERN!
OC_PORT=9200                  # Port (Standard: 9200)
OC_DIR="/opt/opencloud"       # Installationsverzeichnis
```

---

## Web-Apps

Das Script installiert automatisch alle verfügbaren Web-Extensions aus dem offiziellen [opencloud-eu/web-extensions](https://github.com/opencloud-eu/web-extensions) Repository. Jede App kann einzeln aktiviert oder deaktiviert werden:

```bash
INSTALL_DRAWIO=true          # Draw.io – Diagramme & Flowcharts
INSTALL_UNZIP=true           # ZIP-Archive direkt im Browser entpacken
INSTALL_JSONVIEWER=true      # JSON-Dateien formatiert anzeigen
INSTALL_PROGRESSBARS=true    # Bessere Upload-Fortschrittsbalken
INSTALL_MAPS=true            # Geodaten & GPX-Kartenansichten
INSTALL_EXTERNAL_SITES=true  # Externe Webseiten einbinden
INSTALL_CAST=true            # Bilder/Videos auf Chromecast streamen
INSTALL_IMPORTER=true        # Import aus Google Drive, Dropbox etc.
INSTALL_ARCADE=true          # Kleine Spielesammlung
```

Apps sind im Browser über den **App-Wechsler** (9-Punkte-Symbol oben links) erreichbar.

---

## Was das Script installiert

1. **System-Pakete** – curl, wget, jq, unzip, openssl, etc.
2. **Docker CE** – direkt aus dem offiziellen Docker-Repository (arm64)
3. **Docker Compose** (v2, als Plugin)
4. **OpenCloud** – via `opencloudeu/opencloud-rolling:latest`
5. **Alle Web-Apps** – automatisch vom GitHub Releases API
6. **Systemd-Service** – für automatischen Start nach Reboot

### Verzeichnisstruktur

```
/opt/opencloud/
├── docker-compose.yml     # Docker Compose Konfiguration
├── .env                   # Umgebungsvariablen
├── config/                # OpenCloud Konfiguration → /etc/opencloud
│   ├── opencloud.yaml
│   └── apps/              # Web-Extensions
│       ├── draw-io/
│       ├── unzip/
│       └── ...
└── data/                  # Nutzerdaten → /var/lib/opencloud
```

---

## Nützliche Befehle

```bash
# Logs live anzeigen
docker compose -f /opt/opencloud/docker-compose.yml logs -f

# Container neu starten
docker compose -f /opt/opencloud/docker-compose.yml restart

# Stoppen
docker compose -f /opt/opencloud/docker-compose.yml down

# Starten
docker compose -f /opt/opencloud/docker-compose.yml up -d

# Installierte Apps prüfen
docker exec opencloud ls /etc/opencloud/apps/

# OpenCloud Version
docker exec opencloud opencloud version
```

---

## Fehlersuche

**Apps werden nicht angezeigt**
```bash
docker compose -f /opt/opencloud/docker-compose.yml restart
# Danach Browser mit Strg+Shift+R hart neu laden
```

**"config file already exists" beim Start**
Das ist kein Fehler – das Script ignoriert das mit `init || true` automatisch.

**Container startet nicht**
```bash
docker logs opencloud | tail -50
```

**Port bereits belegt**
```bash
# Prüfen was Port 9200 belegt
ss -tlnp | grep 9200
# Anderen Port im Script setzen: OC_PORT=9201
```

**Firewall blockiert Zugriff**
```bash
sudo ufw allow 9200/tcp
```

---

## Deinstallation

```bash
# Container stoppen und entfernen
docker compose -f /opt/opencloud/docker-compose.yml down

# Systemd-Service entfernen
sudo systemctl disable opencloud
sudo rm /etc/systemd/system/opencloud.service
sudo systemctl daemon-reload

# Daten löschen (unwiderruflich!)
sudo rm -rf /opt/opencloud
```

---

## Links

- [OpenCloud Website](https://opencloud.eu)
- [OpenCloud Dokumentation](https://docs.opencloud.eu)
- [Web-Extensions GitHub](https://github.com/opencloud-eu/web-extensions)
- [Docker Hub – opencloud-rolling](https://hub.docker.com/r/opencloudeu/opencloud-rolling)
