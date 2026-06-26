# GOST SOCKS5+TLS (Let's Encrypt IP)

Docker-прокси **SOCKS5 с логином/паролем** и **TLS** (Let's Encrypt на IP, автообновление через cron).

## Быстрый старт (новый VPS)

### 1. Скачать

```bash
git clone https://github.com/YOUR_USER/gost-socks-proxy.git
cd gost-socks-proxy
```

### 2. Настроить переменные

```bash
cp .env.example .env
nano .env
```

| Переменная | Обязательно | Описание |
|------------|-------------|----------|
| `LEGO_EMAIL` | **да** | Email для Let's Encrypt (реальный домен, напр. `you@gmail.com`) |
| `GOST_USER` | нет | Логин SOCKS5 (по умолчанию `proxy`) |
| `GOST_PASSWORD` | нет | Пароль; пусто = сгенерируется при установке |
| `SERVER_IP` | нет | IP VPS; пусто = определится автоматически |
| `GOST_PORT` | нет | Порт прокси (по умолчанию `1443`) |

### 3. Установить одной командой

```bash
sudo ./install.sh
```

Скрипт:
- установит **lego** (если нет);
- получит **Let's Encrypt** сертификат на IP (нужен открытый **TCP 80**);
- поднимет контейнер **GOST**;
- настроит **cron** (продление cert 2× в день);
- выведет данные подключения в `credentials.txt`.

### 4. Открыть порт в firewall облака

Разрешите **TCP `GOST_PORT`** (по умолчанию `1443`) inbound в security group вашего VPS.

---

## Подключение клиента

После установки смотрите `credentials.txt`:

```bash
cat credentials.txt
```

Пример URI:

```
socks5+tls://USER:PASS@YOUR_IP:1443?notls=true
```

**sing-box** (outbound):

```json
{
  "type": "socks",
  "server": "YOUR_IP",
  "server_port": 1443,
  "username": "proxy",
  "password": "YOUR_PASSWORD",
  "version": "5",
  "tls": { "enabled": true }
}
```

Telegram напрямую к TLS-порту не подключается — нужен локальный клиент (sing-box / GOST), который поднимет SOCKS на `127.0.0.1:1080`.

---

## Управление

```bash
# Перезапуск прокси
sudo ./start-gost.sh

# Ручное продление сертификата
sudo ./scripts/renew-certs.sh

# Лог продления
sudo tail -f /var/log/gost-socks-proxy-renew.log

# Срок действия cert
openssl x509 -in certs/fullchain.pem -noout -dates

# Удалить контейнер и cron (cert-файлы останутся)
sudo ./uninstall.sh
```

---

## Требования

- Linux VPS с **Docker**
- Публичный IPv4
- **Порт 80** свободен на ~10 сек при первой выдаче и при продлении cert
- Порт прокси (`GOST_PORT`) не занят другим сервисом

---

## Файлы (что в git, что нет)

| В git | Не в git (секреты/генерируется) |
|-------|----------------------------------|
| `.env.example`, `gost.yml.template` | `.env`, `gost.yml`, `credentials.txt` |
| `install.sh`, `scripts/` | `certs/*.pem` |

---

## Переустановка / другой VPS

```bash
git pull
cp .env.example .env   # или скопируйте свой .env
nano .env
sudo ./install.sh
```
