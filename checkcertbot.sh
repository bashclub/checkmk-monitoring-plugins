#!/bin/bash

# Einfacher Checkmk Local Check für Certbot-Zertifikate
# Prüft alle cert.pem unter /etc/letsencrypt/live und gibt Status + SANs aus.
# Schwellwerte:
#   <= 0 Tage      -> CRITICAL (abgelaufen)
#   1–14 Tage      -> CRITICAL
#   15–30 Tage     -> WARNING
#   > 30 Tage      -> OK

CERTBOT_LIVE_DIR="/etc/letsencrypt/live"
WARN_DAYS=30
CRIT_DAYS=14

# Header für Checkmk Local Checks
echo "<<<local>>>"

# Abhängigkeiten prüfen
if ! command -v openssl >/dev/null 2>&1; then
    echo "3 Certbot_Certs - UNKNOWN: openssl nicht gefunden"
    exit 0
fi

if [ ! -d "$CERTBOT_LIVE_DIR" ]; then
    echo "3 Certbot_Certs - UNKNOWN: Verzeichnis $CERTBOT_LIVE_DIR nicht gefunden"
    exit 0
fi

NOW_EPOCH=$(date +%s)

# Alle Certbot-Zertifikate durchgehen
for CERT_DIR in "$CERTBOT_LIVE_DIR"/*; do
    [ -d "$CERT_DIR" ] || continue

    CERT_NAME="$(basename "$CERT_DIR")"
    CERT_FILE="$CERT_DIR/cert.pem"

    if [ ! -f "$CERT_FILE" ]; then
        # Kein cert.pem in diesem Verzeichnis – überspringen
        continue
    fi

    # Ablaufdatum auslesen
    END_DATE_RAW=$(openssl x509 -enddate -noout -in "$CERT_FILE" 2>/dev/null | cut -d= -f2)

    if [ -z "$END_DATE_RAW" ]; then
        echo "3 Certbot_${CERT_NAME} - UNKNOWN: Konnte Ablaufdatum nicht lesen ($CERT_FILE)"
        continue
    fi

    # Ablaufzeit in Epoch umrechnen
    END_EPOCH=$(date -d "$END_DATE_RAW" +%s 2>/dev/null)
    if [ -z "$END_EPOCH" ]; then
        echo "3 Certbot_${CERT_NAME} - UNKNOWN: Konnte Ablaufdatum nicht parsen: $END_DATE_RAW"
        continue
    fi

    SECONDS_LEFT=$((END_EPOCH - NOW_EPOCH))
    DAYS_LEFT=$((SECONDS_LEFT / 86400))

    # SANs ermitteln (Subject Alternative Names)
    SANS=$(openssl x509 -noout -text -in "$CERT_FILE" 2>/dev/null \
        | grep -A1 "Subject Alternative Name" \
        | tail -n1 \
        | sed 's/ *DNS://g' \
        | sed 's/, */,/g' \
        | xargs)

    # Status bestimmen
    if [ "$SECONDS_LEFT" -le 0 ]; then
        STATE=2
        STATE_TEXT="CRITICAL"
        MSG="Zertifikat abgelaufen (seit $((-DAYS_LEFT)) Tagen)"
    elif [ "$DAYS_LEFT" -le "$CRIT_DAYS" ]; then
        STATE=2
        STATE_TEXT="CRITICAL"
        MSG="Zertifikat läuft sehr bald ab (in ${DAYS_LEFT} Tagen)"
    elif [ "$DAYS_LEFT" -le "$WARN_DAYS" ]; then
        STATE=1
        STATE_TEXT="WARNING"
        MSG="Zertifikat läuft bald ab (in ${DAYS_LEFT} Tagen)"
    else
        STATE=0
        STATE_TEXT="OK"
        MSG="Zertifikat gültig (noch ${DAYS_LEFT} Tage)"
    fi

    # Optionales Perfdata-Beispiel (kannst du bei Bedarf anpassen oder entfernen):
    #   days_left=N
    #   0/1/2 entsprechen OK/WARN/CRIT
    echo "${STATE} Certbot_${CERT_NAME} days_left=${DAYS_LEFT};;0; ${STATE_TEXT}: ${MSG}, NotAfter: ${END_DATE_RAW}, SANs: ${SANS}"
done
