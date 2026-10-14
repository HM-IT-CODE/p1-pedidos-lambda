#!/bin/sh
cd /mnt/d/2026/LABS/p1-pedidos-lambda || exit 1
PRUEBA_DLQ=1 sh scripts/aws-real.sh probar 2>&1 | grep -vE '^\s*$'
