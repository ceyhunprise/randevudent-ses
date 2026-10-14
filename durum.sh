#!/usr/bin/env bash
# Servislerin durumunu gösterir. Kullanım: sudo bash durum.sh
cd "$(dirname "$0")"
set -a; . ./.env 2>/dev/null; set +a

docker compose ps --format "table {{.Service}}\t{{.Status}}"
echo
if docker compose ps agent --format "{{.Status}}" 2>/dev/null | grep -q "Up"; then
  printf "\033[1;32mHazır.\033[0m Test sayfası: https://%s  (şifre: %s)\n" "$DOMAIN" "$TEST_SIFRESI"
else
  printf "\033[1;33mHenüz hazır değil.\033[0m Modeller iniyor olabilir; birkaç dakika sonra tekrar çalıştır.\n"
  echo "Son kayıtlar (dil modeli):"
  docker compose logs --tail 5 llm 2>/dev/null
fi
echo
echo "GPU kullanımı:"
nvidia-smi --query-gpu=memory.used,memory.total,utilization.gpu --format=csv
