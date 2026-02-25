#!/bin/bash
# ============================================================
# OpenCloud ARM64 Install Script – inkl. ALLE Web-Apps
# Ubuntu 24.04 / Debian 12 (ARM64)
# ============================================================

set -e

# ─── Konfiguration ────────────────────────────────────────────
OC_DIR="/opt/opencloud"
OC_DATA="$OC_DIR/data"
OC_CONFIG="$OC_DIR/config"
OC_APPS="$OC_CONFIG/apps"     # → im Container: /etc/opencloud/apps
ADMIN_PASSWORD="Admin1234!"   # <── BITTE ÄNDERN!
OC_PORT=9200

# ─── App-Auswahl: true = installieren, false = überspringen ───
# Alle verfügbaren Apps aus github.com/opencloud-eu/web-extensions
INSTALL_DRAWIO=true          # Draw.io – Diagramme & Flowcharts
INSTALL_UNZIP=true           # ZIP-Archive direkt im Browser entpacken
INSTALL_JSONVIEWER=true      # JSON-Dateien hübsch formatiert anzeigen
INSTALL_PROGRESSBARS=true    # Bessere Upload-Fortschrittsbalken
INSTALL_MAPS=true            # Geodaten & Kartenansichten (z.B. GPX)
INSTALL_EXTERNAL_SITES=true  # Externe Webseiten als App einbinden
INSTALL_CAST=true            # Bilder/Videos auf Chromecast streamen
INSTALL_IMPORTER=true        # Import aus Google Drive, Dropbox, etc.
INSTALL_ARCADE=true          # Kleine Spielesammlung

# ─── Farben ───────────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
appmsg(){ echo -e "${CYAN}[APP] ${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ─── Root-Check ───────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Bitte als root oder mit sudo ausführen!"

ARCH=$(uname -m)
[[ "$ARCH" != "aarch64" ]] && warn "Kein ARM64 erkannt (Arch: $ARCH)"

SERVER_IP=$(hostname -I | awk '{print $1}')
OC_URL="https://${SERVER_IP}:${OC_PORT}"

info "Starte OpenCloud Installation auf ${SERVER_IP}..."

# ─── System-Abhängigkeiten ────────────────────────────────────
info "Installiere Abhängigkeiten..."
apt-get update -qq
apt-get install -y \
    curl wget ca-certificates gnupg lsb-release \
    apt-transport-https software-properties-common \
    openssl jq net-tools unzip

# ─── Docker ───────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    info "Installiere Docker..."
    DISTRO_ID=$(. /etc/os-release && echo "$ID")
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    curl -fsSL "https://download.docker.com/linux/${DISTRO_ID}/gpg" \
        | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/${DISTRO_ID} $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    info "Docker: $(docker --version)"
else
    info "Docker bereits vorhanden."
fi

# ─── Verzeichnisse ────────────────────────────────────────────
info "Erstelle Verzeichnisse..."
mkdir -p "$OC_CONFIG" "$OC_DATA" "$OC_APPS"
chown -R 1000:1000 "$OC_CONFIG" "$OC_DATA"

# ─── Funktion: App von GitHub herunterladen ──────────────────
install_extension() {
    local APP_NAME="$1"      # Tag-Prefix, z.B. "draw-io"
    local APP_SLUG="$2"      # ZIP-Dateiname-Prefix, z.B. "draw-io"
    local DISPLAY_NAME="$3"

    appmsg "Installiere ${DISPLAY_NAME}..."

    # Neuesten Release-Tag ermitteln
    local LATEST
    LATEST=$(curl -s "https://api.github.com/repos/opencloud-eu/web-extensions/releases" \
        | jq -r --arg app "${APP_NAME}-v" \
        '[.[] | select(.tag_name | startswith($app))] | first | .tag_name')

    if [[ -z "$LATEST" || "$LATEST" == "null" ]]; then
        warn "${DISPLAY_NAME}: Kein Release gefunden – überspringe."
        return
    fi

    # Versionsnummer extrahieren: "draw-io-v1.2.3" → "1.2.3"
    local VERSION
    VERSION=$(echo "$LATEST" | grep -oP '\d+\.\d+\.\d+')
    local ZIP_NAME="${APP_SLUG}-${VERSION}.zip"
    local DL_URL="https://github.com/opencloud-eu/web-extensions/releases/download/${LATEST}/${ZIP_NAME}"

    appmsg "${DISPLAY_NAME} v${VERSION} – lade herunter..."

    local TMP_FILE="/tmp/${ZIP_NAME}"
    if wget -q --show-progress -O "$TMP_FILE" "$DL_URL"; then
        rm -rf "${OC_APPS}/${APP_SLUG}"
        unzip -q -o "$TMP_FILE" -d "$OC_APPS"
        rm -f "$TMP_FILE"
        chown -R 1000:1000 "$OC_APPS"
        appmsg "${DISPLAY_NAME} ✓"
    else
        warn "${DISPLAY_NAME}: Download fehlgeschlagen!"
        warn "Manuell prüfen: https://github.com/opencloud-eu/web-extensions/releases"
        rm -f "$TMP_FILE"
    fi
}

# ─── Alle Apps installieren ───────────────────────────────────
info "Installiere Web-Extensions nach: $OC_APPS"

[[ "$INSTALL_DRAWIO" == true ]]         && install_extension "draw-io"        "draw-io"        "Draw.io"
[[ "$INSTALL_UNZIP" == true ]]          && install_extension "unzip"          "unzip"          "Unzip"
[[ "$INSTALL_JSONVIEWER" == true ]]     && install_extension "json-viewer"    "json-viewer"    "JSON Viewer"
[[ "$INSTALL_PROGRESSBARS" == true ]]   && install_extension "progress-bars"  "progress-bars"  "Progress Bars"
[[ "$INSTALL_MAPS" == true ]]           && install_extension "maps"           "maps"           "Maps"
[[ "$INSTALL_EXTERNAL_SITES" == true ]] && install_extension "external-sites" "external-sites" "External Sites"
[[ "$INSTALL_CAST" == true ]]           && install_extension "cast"           "cast"           "Chromecast"
[[ "$INSTALL_IMPORTER" == true ]]       && install_extension "importer"       "importer"       "Importer"
[[ "$INSTALL_ARCADE" == true ]]         && install_extension "arcade"         "arcade"         "Arcade"

# ─── Docker Compose ───────────────────────────────────────────
info "Erstelle Docker Compose Konfiguration..."

cat > "$OC_DIR/.env" <<EOF
OC_URL=${OC_URL}
OC_INSECURE=true
PROXY_HTTP_ADDR=0.0.0.0:${OC_PORT}
IDM_ADMIN_PASSWORD=${ADMIN_PASSWORD}
EOF

cat > "$OC_DIR/docker-compose.yml" <<EOF
services:
  opencloud:
    image: opencloudeu/opencloud-rolling:latest
    container_name: opencloud
    restart: unless-stopped
    entrypoint: /bin/sh
    # init || true: Fehler ignorieren wenn Config schon existiert, dann Server starten
    command: ["-c", "opencloud init || true; opencloud server"]
    ports:
      - "${OC_PORT}:9200"
    environment:
      OC_URL: \${OC_URL}
      OC_INSECURE: \${OC_INSECURE}
      PROXY_HTTP_ADDR: \${PROXY_HTTP_ADDR}
      IDM_ADMIN_PASSWORD: \${IDM_ADMIN_PASSWORD}
      OC_DATA_DIR: /var/lib/opencloud
    volumes:
      # Config inkl. apps/ Unterordner → /etc/opencloud/apps im Container
      - ${OC_CONFIG}:/etc/opencloud
      - ${OC_DATA}:/var/lib/opencloud
    healthcheck:
      test: ["CMD", "curl", "-fk", "https://localhost:9200/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
EOF

# ─── Starten ──────────────────────────────────────────────────
info "Starte OpenCloud..."
cd "$OC_DIR"
docker compose up -d

# ─── Systemd-Service ──────────────────────────────────────────
info "Erstelle Systemd-Service für Autostart..."
cat > /etc/systemd/system/opencloud.service <<EOF
[Unit]
Description=OpenCloud
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${OC_DIR}
ExecStart=docker compose up -d
ExecStop=docker compose down
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable opencloud.service

# ─── Firewall ─────────────────────────────────────────────────
if command -v ufw &>/dev/null && ufw status | grep -q "active"; then
    ufw allow "$OC_PORT/tcp"
    info "UFW: Port $OC_PORT geöffnet."
fi

# ─── Neustart damit Apps geladen werden ──────────────────────
info "Starte Container neu damit alle Apps geladen werden..."
cd "$OC_DIR"
docker compose restart
sleep 5

# ─── Warten bis OpenCloud bereit ist ─────────────────────────
info "Warte auf OpenCloud (bis zu 120 Sekunden)..."
for i in $(seq 1 24); do
    curl -fks "$OC_URL/health" &>/dev/null && { echo; info "OpenCloud ist bereit!"; break; }
    echo -n "."
    sleep 5
    [[ $i -eq 24 ]] && { echo; warn "Timeout – OpenCloud startet noch. Logs prüfen."; }
done

# ─── Installierte Apps anzeigen ───────────────────────────────
echo ""
echo -e "${CYAN}Installierte Web-Apps in ${OC_APPS}:${NC}"
if ls "$OC_APPS" 2>/dev/null | grep -q .; then
    ls "$OC_APPS" | while read -r d; do
        echo -e "  ✓ ${d}"
    done
else
    echo "  (keine Apps installiert)"
fi

# ─── Fertig ───────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        OpenCloud Installation abgeschlossen!         ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  🌐 URL:       ${YELLOW}${OC_URL}${NC}"
echo -e "  👤 Benutzer:  ${YELLOW}admin${NC}"
echo -e "  🔑 Passwort:  ${YELLOW}${ADMIN_PASSWORD}${NC}"
echo ""
echo -e "  ⚠️  Zertifikat ist selbstsigniert → Browserwarnung einfach bestätigen."
echo ""
echo -e "  Logs:       ${YELLOW}docker compose -f $OC_DIR/docker-compose.yml logs -f${NC}"
echo -e "  Stoppen:    ${YELLOW}docker compose -f $OC_DIR/docker-compose.yml down${NC}"
echo -e "  Neustarten: ${YELLOW}docker compose -f $OC_DIR/docker-compose.yml restart${NC}"
echo ""
