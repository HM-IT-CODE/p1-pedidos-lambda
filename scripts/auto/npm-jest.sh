#!/bin/sh
cd /mnt/d/2026/LABS/p1-pedidos-lambda || exit 1
npm install -D jest@29 @types/jest@29 @swc/core @swc/jest aws-sdk-client-mock@4 > /tmp/p1-npm.log 2>&1
echo "FIN $?" >> /tmp/p1-npm.log
