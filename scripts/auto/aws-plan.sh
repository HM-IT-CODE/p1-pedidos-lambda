#!/bin/sh
cd /mnt/d/2026/LABS/p1-pedidos-lambda || exit 1
sh scripts/aws-real.sh plan 2>&1 | grep -E '# aws_|Plan:|Error|error|Warning' | sed 's/ will be created//'
