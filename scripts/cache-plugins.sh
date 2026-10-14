#!/bin/sh
# Arreglo del "timeout while waiting for plugin to start":
# el plugin de AWS (~600 MB) vivía en infra/.terraform/ = disco de Windows (/mnt/d, lento desde Linux).
# Con un plugin_cache_dir en el disco Linux, tofu guarda ahí los plugins y en el proyecto
# deja solo un ENLACE (symlink). Sirve para todos los proyectos y se configura una vez.
mkdir -p /root/.tofu-plugins
grep -q plugin_cache_dir /root/.tofurc 2>/dev/null || echo 'plugin_cache_dir = "/root/.tofu-plugins"' >> /root/.tofurc
echo "== /root/.tofurc:"; cat /root/.tofurc
cd /mnt/d/2026/LABS/p1-pedidos-lambda
du -sh infra/.terraform/providers 2>/dev/null
rm -rf infra/.terraform/providers
tofu -chdir=infra init -no-color | grep -E 'Installing|Installed|Using|success|Error'
echo "== ahora el proyecto solo tiene enlaces:"
find infra/.terraform/providers -maxdepth 5 -type l | head -3
du -sh /root/.tofu-plugins
echo "== prueba de velocidad:"
time tofu -chdir=infra validate -no-color
