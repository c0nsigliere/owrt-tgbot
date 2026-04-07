# owrt-tgbot

Telegram bot for monitoring OpenWrt routers. Runs directly on the router as a procd service with zero extra runtime dependencies.

Built with [ucode](https://ucode.mein.io/) — a lightweight scripting language preinstalled on OpenWrt 22.03+.

## Features

**Commands** — send from Telegram to get instant info:

| Command | Description |
|---------|-------------|
| `/status` | System overview: model, uptime, load, RAM, CPU temp, WAN IP |
| `/devices` | Connected devices with online status, IP, MAC, Wi-Fi signal. Paginated with inline buttons |
| `/traffic` | WAN traffic stats: today, week, month, top days (via vnstat) |
| `/updates` | Available package updates (supports both opkg and apk) |
| `/save` | Flush runtime state to persistent storage |
| `/help` | List available commands |

**Alerts** — automatic notifications via cron (every minute):

| Alert | Description |
|-------|-------------|
| New device | Unknown MAC appeared on the network |
| WAN status | WAN link went down or came back up |
| CPU temperature | Temperature exceeded configured threshold |

## Requirements

- OpenWrt 22.03+ (ucode preinstalled)
- `curl` and `ca-bundle` packages
- `vnstat` for traffic monitoring (optional)
- A Telegram bot token from [@BotFather](https://t.me/BotFather)

## Quick Start

### 1. Install dependencies on the router

```bash
# OpenWrt 25.x (apk)
apk add curl ca-bundle vnstat

# OpenWrt 22.x-24.x (opkg)
opkg update && opkg install curl ca-bundle vnstat
```

### 2. Configure vnstat (recommended)

By default vnstat writes its database to flash every 30 minutes, which means
`/traffic` data can be stale. Move the database to RAM and back up to flash
on shutdown to get fresh stats without wearing out NAND:

```bash
ssh root@192.168.1.1

# Database in RAM (tmpfs), save every minute (free in RAM)
sed -i 's|^DatabaseDir.*|DatabaseDir "/tmp/vnstat"|' /etc/vnstat.conf
sed -i 's|^SaveInterval.*|SaveInterval 1|' /etc/vnstat.conf

# Persistent backup dir for restoring after reboot
uci set vnstat.@vnstat[0].backup_dir='/var/lib/vnstat'
uci commit vnstat

# Hourly backup from RAM to flash (max 24 writes/day)
(crontab -l 2>/dev/null | grep -v 'vnstat.*backup'
 echo "0 * * * * cp -f /tmp/vnstat/wan /tmp/vnstat/br-lan /var/lib/vnstat/ 2>/dev/null"
) | crontab -
```

Also add `stop_service` to `/etc/init.d/vnstat` so the database is saved on
shutdown/restart — see `files/vnstat-init-patch.sh`.

### 3. Deploy

```bash
# From your dev machine
make deploy ROUTER_HOST=192.168.1.1
```

### 4. Configure

```bash
ssh root@192.168.1.1

uci set owrt-tgbot.main.bot_token='YOUR_BOT_TOKEN'
uci set owrt-tgbot.main.allowed_chat_id='YOUR_CHAT_ID'
uci commit owrt-tgbot
```

Get your chat ID by sending `/start` to [@userinfobot](https://t.me/userinfobot).

### 5. Start

```bash
ssh root@192.168.1.1

service owrt-tgbot enable   # autostart on boot
service owrt-tgbot start
```

### 6. Set up alerts (optional)

Add to the router's crontab:

```bash
(crontab -l; echo "* * * * * /usr/bin/ucode -S /usr/lib/owrt-tgbot/alerts/runner.uc") | crontab -
```

## Configuration

All settings are stored in UCI (`/etc/config/owrt-tgbot`):

```
config owrt-tgbot 'main'
    option bot_token ''              # Telegram bot token (required)
    list allowed_chat_id ''          # Allowed Telegram chat IDs
    option poll_timeout '30'         # Long-polling timeout (seconds)
    option log_level 'info'          # debug | info | error
    option proxy_enabled '0'         # Enable SOCKS5 proxy
    option proxy_url ''              # socks5h://user:pass@host:port

config alerts 'alerts'
    option enabled '1'               # Master switch for all alerts
    option new_device '1'            # Alert on unknown MAC addresses
    option wan_status '1'            # Alert on WAN up/down
    option temp_threshold '1'        # Alert on high CPU temperature
    option temp_limit '85'           # Temperature threshold (Celsius)

config traffic 'traffic'
    option interface 'wan'           # WAN interface for vnstat
    option warn_daily_gb '0'         # Daily traffic warning (0 = disabled)
```

## Proxy Support

For environments where Telegram API is blocked, enable SOCKS5 proxy:

```bash
uci set owrt-tgbot.main.proxy_enabled='1'
uci set owrt-tgbot.main.proxy_url='socks5h://user:pass@host:port'
uci commit owrt-tgbot
service owrt-tgbot restart
```

Use `socks5h://` (not `socks5://`) to resolve DNS through the proxy.

## Development

### Prerequisites (WSL2 / Linux)

```bash
sudo apt install build-essential cmake libjson-c-dev pkg-config
git clone https://github.com/jow-/ucode.git && cd ucode
cmake -DUBUS_SUPPORT=OFF -DUCI_SUPPORT=OFF -DULOOP_SUPPORT=OFF .
make && sudo make install
```

### Running locally

Create `.env` in the project root:

```
BOT_TOKEN=123456:ABC-DEF
ALLOWED_CHAT_IDS=123456789
POLL_TIMEOUT=30
LOG_LEVEL=debug
PROXY_ENABLED=0
```

```bash
ucode -S src/main.uc
```

### Testing

```bash
make test
```

### Makefile targets

| Target | Description |
|--------|-------------|
| `make test` | Run test suite |
| `make deploy` | Deploy to router via SCP |
| `make restart` | Restart service on router |
| `make dev` | Test + deploy + restart |
| `make status` | Show service status and recent logs |
| `make logs` | Tail live logs on router |
| `make check-deps` | Verify router has required packages |

## Project Structure

```
src/
  main.uc              Entry point
  config.uc            UCI / .env config loader
  core/
    bot.uc             Update loop, command routing, callback handling
    telegram.uc        Telegram Bot API client (curl-based)
  commands/            Command modules (loadfile)
    status.uc          /status
    devices.uc         /devices (with inline keyboard pagination)
    traffic.uc         /traffic
    updates.uc         /updates (async)
    help.uc            /help
    save.uc            /save
  alerts/              Alert modules (loadfile)
    runner.uc          Cron entry point
    new_device.uc      New device detection
    wan_status.uc      WAN link monitoring
    temp_threshold.uc  CPU temperature monitoring
  notify/
    telegram.uc        Rate-limited notification backend
  lib/
    util.uc            Formatting, icons, file I/O helpers
    ubus_wrapper.uc    ubus abstraction (real / fixture)
    devices.uc         ARP + DHCP + Wi-Fi device aggregation
    vnstat.uc          vnstat JSON parser (v1 + v2 compat)
    opkg.uc            Package manager abstraction (opkg + apk)
tests/
  run.uc               Test runner
  test_*.uc            Test suites
fixtures/              Mock data for dev/test
files/
  owrt-tgbot.init      procd init script
  owrt-tgbot.config    Default UCI config
  owrt-tgbot.cron      Cron entry for alerts
```

## License

MIT
