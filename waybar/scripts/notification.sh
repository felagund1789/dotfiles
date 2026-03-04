#!/usr/bin/env sh

if ! command -v swaync-client >/dev/null 2>&1; then
  printf '{"text":"","class":"disabled","tooltip":"swaync-client not found"}\n'
  exit 0
fi

count="$(swaync-client -c 2>/dev/null)"

if [ -z "$count" ]; then
  count=0
fi

if [ "$count" -gt 0 ] 2>/dev/null; then
  printf '{"text":" %s","class":"has-notification","tooltip":"%s unread notification(s)"}\n' "$count" "$count"
else
  printf '{"text":"","class":"none","tooltip":"No unread notifications"}\n'
fi
