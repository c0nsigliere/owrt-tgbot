ROUTER_HOST ?= 192.168.1.1
INSTALL_DIR = /usr/lib/owrt-tgbot
STATE_DIR = /etc/owrt-tgbot/state
SCP = scp -O

.PHONY: test deploy restart enable dev clean status logs check-deps

test:
	ucode -S tests/run.uc

deploy:
	ssh root@$(ROUTER_HOST) "mkdir -p $(INSTALL_DIR) $(STATE_DIR) /tmp/owrt-tgbot/state /tmp/owrt-tgbot/tasks"
	$(SCP) -r src/* root@$(ROUTER_HOST):$(INSTALL_DIR)/
	$(SCP) files/owrt-tgbot.init root@$(ROUTER_HOST):/etc/init.d/owrt-tgbot
	ssh root@$(ROUTER_HOST) "chmod +x /etc/init.d/owrt-tgbot"
	@ssh root@$(ROUTER_HOST) "grep -q 'midnight.uc' /etc/crontabs/root 2>/dev/null || \
		(echo '0 0 * * * /usr/bin/ucode -S /usr/lib/owrt-tgbot/cron/midnight.uc' >> /etc/crontabs/root && /etc/init.d/cron restart)"
	@# Only copy config if it doesn't already exist (don't overwrite token)
	@ssh root@$(ROUTER_HOST) "[ -f /etc/config/owrt-tgbot ]" 2>/dev/null || \
		$(SCP) files/owrt-tgbot.config root@$(ROUTER_HOST):/etc/config/owrt-tgbot

restart:
	ssh root@$(ROUTER_HOST) "service owrt-tgbot restart"

enable:
	ssh root@$(ROUTER_HOST) "service owrt-tgbot enable"

dev: test deploy restart

clean:
	rm -rf /tmp/owrt-tgbot-test-*

# Check that router has required packages
check-deps:
	ssh root@$(ROUTER_HOST) "which ucode curl && echo 'OK: deps present' || echo 'MISSING: install curl ca-bundle'"

# Show router status
status:
	ssh root@$(ROUTER_HOST) "service owrt-tgbot status 2>/dev/null; logread -e owrt-tgbot | tail -20"

# Tail logs on router
logs:
	ssh root@$(ROUTER_HOST) "logread -f -e owrt-tgbot"
