#!/usr/bin/env bash
set -Eeuo pipefail

SYSTEMD_DIR='/etc/systemd/system'
SERVICE_NAME='HAPCStat'
SERVICE_USER='maxime'
SERVICE_GROUP='maxime'
WorkingDirectory="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RUNNER_PATH="$WorkingDirectory/run.sh"

cat > "$SYSTEMD_DIR/$SERVICE_NAME.service" <<EOF_SERVICE
[Unit]
Description=Home Assistant Stats
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=$SERVICE_USER
Group=$SERVICE_GROUP
ExecStart=$RUNNER_PATH
WorkingDirectory=$WorkingDirectory
Nice=10
IOSchedulingClass=best-effort

[Install]
WantedBy=multi-user.target
EOF_SERVICE


cat > "$SYSTEMD_DIR/$SERVICE_NAME-test.service" <<EOF_TESTSERVICE
[Unit]
Description=Test des statistiques Home Assistant
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=$SERVICE_USER
Group=$SERVICE_GROUP
ExecStart=$RUNNER_PATH
WorkingDirectory=$WorkingDirectory
Nice=10
IOSchedulingClass=best-effort
EOF_TESTSERVICE

cat > "$SYSTEMD_DIR/$SERVICE_NAME.timer" <<EOF_TIMER
[Unit]
Description=Planification du lancement de HAPCStat

[Timer]
OnBootSec=2minutes
OnUnitActiveSec=2minutes
Persistent=true
Unit=$SERVICE_NAME.service

[Install]
WantedBy=timers.target
EOF_TIMER

systemctl daemon-reload
systemd-analyze verify   "$SYSTEMD_DIR/$SERVICE_NAME.service"   "$SYSTEMD_DIR/$SERVICE_NAME-test.service"   "$SYSTEMD_DIR/$SERVICE_NAME.timer"

systemctl enable --now "$SERVICE_NAME.timer"
