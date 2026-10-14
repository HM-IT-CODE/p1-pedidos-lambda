#!/bin/sh
cd /mnt/d/2026/LABS/p1-pedidos-lambda && tofu -chdir=infra apply -auto-approve -no-color 2>&1 | grep -E 'Apply complete|Error' ; sh scripts/auto/plan.sh; tofu -chdir=infra plan -no-color -detailed-exitcode >/dev/null 2>&1; echo "plan exit=$? (0 = sin cambios)"
