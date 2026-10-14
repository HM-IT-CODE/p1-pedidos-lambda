#!/bin/sh
uptime
ls -la /tmp | head -20
ps aux | grep -E "levantar|mini|sleep|tofu|node" | grep -v grep | head -20
cat /tmp/levantar.log 2>/dev/null | tail -30
