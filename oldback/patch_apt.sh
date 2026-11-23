apt clean
rm -rf /var/lib/apt/lists/*
journalctl --vacuum-size=10M 2>/dev/null || true
rm -rf /tmp/* 2>/dev/null || true
