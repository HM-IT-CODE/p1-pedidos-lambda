#!/bin/sh
# ver.sh <nombre> [n] → últimas n líneas del log de un trabajo lanzado con fondo.sh
tail -${2:-40} /root/auto-logs/$1.log 2>&1
