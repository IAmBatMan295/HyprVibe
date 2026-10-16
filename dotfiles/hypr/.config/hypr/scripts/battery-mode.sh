#!/usr/bin/env bash

find_conservation_path() {
  local candidate
  for candidate in \
    "/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode" \
    "/sys/devices/platform/ideapad_acpi/VPC2004:00/conservation_mode"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  find /sys/devices/ -name "conservation_mode" 2>/dev/null | head -n 1
}

CONSERVATION_PATH="$(find_conservation_path)"

if [[ -z "$CONSERVATION_PATH" || ! -f "$CONSERVATION_PATH" ]]; then
  echo ""
  echo "  ❌ Conservation Mode not supported or plugin not installed on this hardware."
  echo ""
  notify-send -u normal "Battery Mode" "Conservation mode not supported on this hardware" 2>/dev/null || true
  sleep 2
  exit 1
fi

current=$(cat "$CONSERVATION_PATH" 2>/dev/null | tr -d '[:space:]')

echo ""
if [[ "$current" == "1" ]]; then
  echo "  Current Mode: 🔋 Conservation Mode (60% cap)"
elif [[ "$current" == "0" ]]; then
  echo "  Current Mode: ⚡ Normal Mode (100% charge)"
else
  echo "  Current Mode: ❓ Unknown (read: '$current')"
fi

echo ""
echo "  1) 🔋 Conservation Mode (60% cap)"
echo "  2) ⚡ Normal Mode (100% charge)"
echo ""
read -rp "  Pick [1/2]: " choice

case "$choice" in
  1)
    echo 1 | sudo tee "$CONSERVATION_PATH" > /dev/null
    echo ""
    echo "  ✅ Switched to Conservation Mode"
    ;;
  2)
    echo 0 | sudo tee "$CONSERVATION_PATH" > /dev/null
    echo ""
    echo "  ✅ Switched to Normal Mode"
    ;;
  *)
    echo ""
    echo "  ❌ Invalid choice"
    ;;
esac

sleep 1
