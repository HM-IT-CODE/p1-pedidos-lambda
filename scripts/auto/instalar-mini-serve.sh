#!/bin/sh
# Instala mini serve como servicio de systemd: arranca solo al prender WSL.
cp /mnt/d/2026/LABS/mini-docker/mini-serve.service /etc/systemd/system/mini-serve.service
systemctl daemon-reload
systemctl enable --now mini-serve 2>&1
sleep 1
systemctl is-active mini-serve
curl -s -m 3 --unix-socket /run/mini/docker.sock http://x/_ping; echo
