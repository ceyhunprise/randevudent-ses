#!/usr/bin/env bash
# RandevuDent sesli asistan — tek komutla kurulum (Ubuntu 22.04 / 24.04, NVIDIA GPU)
# Kullanım:  sudo bash kur.sh
# Kendi alan adın varsa:  sudo DOMAIN=ses.ornek.com bash kur.sh
set -euo pipefail

cd "$(dirname "$0")"
yesil() { printf "\n\033[1;32m==> %s\033[0m\n" "$1"; }
sari()  { printf "\033[1;33m%s\033[0m\n" "$1"; }
kirmizi() { printf "\n\033[1;31m%s\033[0m\n" "$1"; }

if [ "$(id -u)" -ne 0 ]; then
  kirmizi "Bu betiği 'sudo bash kur.sh' ile çalıştır."
  exit 1
fi

# 1) GPU sürücüsü
yesil "1/6 GPU kontrol ediliyor"
if ! command -v nvidia-smi >/dev/null 2>&1 || ! nvidia-smi >/dev/null 2>&1; then
  sari "NVIDIA sürücüsü bulunamadı, kuruluyor (birkaç dakika sürer)..."
  apt-get update -y
  apt-get install -y ubuntu-drivers-common
  ubuntu-drivers autoinstall
  kirmizi "Sürücü kuruldu. Sunucuyu yeniden başlat (sudo reboot), sonra 'sudo bash kur.sh' komutunu tekrar çalıştır."
  exit 0
fi
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
GPU_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' ')

# 2) Docker
yesil "2/6 Docker kontrol ediliyor"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi
docker --version

# 3) Docker'ın GPU'yu görmesi (NVIDIA Container Toolkit)
yesil "3/6 Docker GPU desteği kontrol ediliyor"
if ! command -v nvidia-ctk >/dev/null 2>&1; then
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor --yes -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    > /etc/apt/sources.list.d/nvidia-container-toolkit.list
  apt-get update -y
  apt-get install -y nvidia-container-toolkit
fi
nvidia-ctk runtime configure --runtime=docker >/dev/null
systemctl restart docker

# 4) Güvenlik duvarı
yesil "4/6 Portlar açılıyor"
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow 22/tcp; ufw allow 80/tcp; ufw allow 443/tcp; ufw allow 7881/tcp; ufw allow 50000:50100/udp
fi
sari "Bulut panelindeki güvenlik grubunda da şu portların açık olduğundan emin ol: 80/TCP, 443/TCP, 7881/TCP, 50000-50100/UDP"

# 5) Ayarlar (.env)
yesil "5/6 Ayarlar hazırlanıyor"
if [ ! -f .env ]; then
  IP=$(curl -fsS https://api.ipify.org || curl -fsS https://ifconfig.me)
  ALAN=${DOMAIN:-$(echo "$IP" | tr '.' '-').sslip.io}
  if [ "${GPU_MB:-0}" -ge 40000 ]; then MODEL="Qwen/Qwen3-14B-AWQ"; ORAN="0.6"; else MODEL="Qwen/Qwen3-8B-AWQ"; ORAN="0.55"; fi
  cp ayarlar.ornek.env .env
  sed -i "s#^DOMAIN=.*#DOMAIN=${ALAN}#" .env
  sed -i "s#^LIVEKIT_API_KEY=.*#LIVEKIT_API_KEY=API$(openssl rand -hex 6)#" .env
  sed -i "s#^LIVEKIT_API_SECRET=.*#LIVEKIT_API_SECRET=$(openssl rand -hex 24)#" .env
  sed -i "s#^TEST_SIFRESI=.*#TEST_SIFRESI=$(openssl rand -hex 4)#" .env
  sed -i "s#^LLM_MODEL=.*#LLM_MODEL=${MODEL}#" .env
  sed -i "s#^LLM_GPU_ORANI=.*#LLM_GPU_ORANI=${ORAN}#" .env
  chmod 600 .env
fi
mkdir -p veri

# 6) Başlat
yesil "6/6 Servisler derleniyor ve başlatılıyor (ilk seferde 10-25 dakika sürebilir)"
docker compose up -d --build

set -a; . ./.env; set +a
yesil "Kurulum başladı"
echo "Modeller arka planda iniyor. Hazır olup olmadığını görmek için:  sudo bash durum.sh"
echo
echo "Test sayfası :  https://${DOMAIN}"
echo "Test şifresi :  ${TEST_SIFRESI}"
echo
sari "Bu iki bilgiyi bir yere not et."
