#!/bin/sh
cd /mnt/d/2026/LABS/p1-pedidos-lambda || exit 1
npx tsc -p . 2>&1 | head -30; echo "TSC $?"
npx jest --selectProjects unit 2>&1 | tail -60
