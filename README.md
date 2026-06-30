# GOST SOCKS5+TLS (Let's Encrypt IP)

Docker-прокси **SOCKS5 с логином/паролем** и **TLS** (Let's Encrypt на IP, автообновление через cron).

## Быстрый старт (новый VPS)

### 1. Скачать

```bash
git clone https://github.com/swtormy/gost-socks-proxy.git
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
| `CHAIN_MODE_FILE` | нет | Файл состояния режима (`direct`/`chain`), по умолчанию `state/mode` |
| `HOP_SERVER_IP` | для chain | IP hop VPS (например, `5.8.34.74`) |
| `HOP_GOST_PORT` | для chain | Порт hop GOST (по умолчанию `1443`) |
| `HOP_GOST_USER` | для chain | Логин hop-прокси |
| `HOP_GOST_PASSWORD` | для chain | Пароль hop-прокси |

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

### Проверка на самом VPS

```bash
sudo ./scripts/test-proxy.sh
# OK: direct exit IP = 93.77.185.169
# OK: chain  exit IP = 5.8.34.74
```

---

## Troubleshooting

### В логах `tls: client offered only unsupported versions: [301]` / `[302]`

**301 = TLS 1.0, 302 = TLS 1.1.** Сервер принимает только TLS 1.2+ — это нормально.

IP вроде `66.132.195.55` — чаще всего **интернет-сканеры** (Censys и т.п.), не ваш клиент. Их можно игнорировать.

### Интернет не работает после «подключения»

**Самая частая причина:** клиент шлёт **обычный SOCKS5 без TLS** на порт `1443`, а сервер ждёт **сначала TLS-handshake**.

| Неправильно | Правильно |
|-------------|-----------|
| Telegram → SOCKS5 → `IP:1443` | sing-box / GOST → **SOCKS5+TLS** → `IP:1443` → локальный SOCKS `127.0.0.1:1080` → Telegram |
| `socks5://user:pass@IP:1443` | `socks5+tls://user:pass@IP:1443?notls=true` |
| Shadowrocket: тип SOCKS5 | Shadowrocket: **SOCKS5 over TLS** |

Порт `1443` — это **TLS-слой**, внутри него SOCKS5. Не путать с «SOCKS5 + шифрование в настройках Telegram».

### Локальный GOST-клиент (универсальный вариант)

На ПК/телефоне с Docker или бинарником GOST:

```bash
gost -L socks5://:1080 \
  -F "socks5+tls://USER:PASS@SERVER_IP:1443?notls=true"
```

Дальше в Telegram/браузере указываете **`127.0.0.1:1080`** (обычный SOCKS5 без TLS).

### sing-box: минимальный конфиг

```json
{
  "outbounds": [{
    "type": "socks",
    "tag": "proxy",
    "server": "SERVER_IP",
    "server_port": 1443,
    "username": "proxy",
    "password": "YOUR_PASSWORD",
    "version": "5",
    "tls": { "enabled": true }
  }],
  "inbounds": [{
    "type": "mixed",
    "tag": "in",
    "listen": "127.0.0.1",
    "listen_port": 1080
  }],
  "route": { "final": "proxy" }
}
```

### Shadowrocket / Surge / Loon

Используйте схему **`socks5+tls://`** или тип **SOCKS5-TLS**, не обычный SOCKS5.

---

## Управление

```bash
# Перезапуск прокси
sudo ./start-gost.sh

# Включить цепочку через hop (93.77 -> 5.8)
sudo ./scripts/chain-on.sh

# Выключить цепочку (прямой выход через 93.77)
sudo ./scripts/chain-off.sh

# Показать текущий режим и фактический exit IP
sudo ./scripts/chain-status.sh

# Ручное продление сертификата
sudo ./scripts/renew-certs.sh

# Лог продления
sudo tail -f /var/log/gost-socks-proxy-renew.log

# Срок действия cert
openssl x509 -in certs/fullchain.pem -noout -dates

# Удалить контейнер и cron (cert-файлы останутся)
sudo ./uninstall.sh
```

### Быстрая ручная проверка режима

```bash
# Проверить текущий внешний IP через локальный self-test
sudo ./scripts/chain-status.sh

# Примеры внешней проверки с клиента:
# https://ifconfig.me
# https://2ip.ru
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
