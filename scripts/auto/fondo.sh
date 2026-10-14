#!/bin/sh
# Corre un comando en segundo plano con log, para no chocar con el límite de 60 s del puente.
# Usa systemd-run: el trabajo queda como una "unidad" de systemd y NO muere cuando se
# cierra la sesión de wsl que lo lanzó (con setsid sí moría). KillMode=process: al terminar,
# systemd no mata lo que el trabajo dejó corriendo (mini serve, supervisores de mini).
#   sh fondo.sh <nombre> <comando...>   → log en /root/auto-logs/<nombre>.log, al final "FIN <código>"
N=$1; shift
mkdir -p /root/auto-logs
rm -f /root/auto-logs/$N.log
systemctl reset-failed "auto-$N" >/dev/null 2>&1
systemd-run --quiet --collect --unit="auto-$N" -p KillMode=process -p WorkingDirectory=/mnt/d/2026/LABS/p1-pedidos-lambda \
  -E PATH="$PATH" -E HOME=/root \
  sh -c '"$@" > /root/auto-logs/'"$N"'.log 2>&1; echo "FIN $?" >> /root/auto-logs/'"$N"'.log' x "$@"
echo "lanzado $N"
