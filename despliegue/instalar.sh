#!/bin/bash
# Instala o actualiza Zentry en el servidor (Ubuntu 24.04 en Lightsail).
# Uso, en el servidor: bash /opt/zentry/despliegue/instalar.sh DOMINIO
# Antes hay que copiar el código a /opt/zentry y crear /opt/zentry/.env.
set -euo pipefail
DOMINIO=${1:?Falta el dominio, p. ej. 18-221-247-181.sslip.io}
APP=/opt/zentry

# Memoria de intercambio de 1 GB: la máquina solo tiene 1 GB de RAM
if [ ! -f /swapfile ]; then
  sudo fallocate -l 1G /swapfile && sudo chmod 600 /swapfile
  sudo mkswap /swapfile >/dev/null && sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
fi

sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3-venv caddy >/dev/null

[ -d $APP/.venv ] || python3 -m venv $APP/.venv
$APP/.venv/bin/pip install -q --upgrade pip
$APP/.venv/bin/pip install -q -r $APP/despliegue/requirements-servidor.txt

cd $APP/Zentry
../.venv/bin/python manage.py migrate --noinput
../.venv/bin/python manage.py collectstatic --noinput -v 0
../.venv/bin/python manage.py check --deploy --fail-level ERROR

sudo cp $APP/despliegue/zentry.service /etc/systemd/system/zentry.service
sed "s/DOMINIO/$DOMINIO/" $APP/despliegue/Caddyfile | sudo tee /etc/caddy/Caddyfile >/dev/null
sudo systemctl daemon-reload
sudo systemctl enable --now zentry
sudo systemctl restart zentry
sudo systemctl reload caddy || sudo systemctl restart caddy
echo "Zentry listo en https://$DOMINIO"
