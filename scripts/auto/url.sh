#!/bin/sh
cd /mnt/d/2026/LABS/p1-pedidos-lambda && tofu -chdir=infra output -raw url_pedidos > url-api.txt && cat url-api.txt
