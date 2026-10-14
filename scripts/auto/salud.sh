#!/bin/sh
echo "== mini serve: $(curl -s -m 3 --unix-socket /run/mini/docker.sock http://x/_ping || echo NO RESPONDE)"
echo "== localstack: $(curl -s -m 3 localhost:4566/_localstack/health | head -c 80 || echo NO)"
mini ps
