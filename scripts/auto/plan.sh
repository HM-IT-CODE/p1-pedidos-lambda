#!/bin/sh
cd /mnt/d/2026/LABS/p1-pedidos-lambda && tofu -chdir=infra plan -no-color 2>&1 | grep -E '^\s+[~+-]|will be|Plan:' | head -30
