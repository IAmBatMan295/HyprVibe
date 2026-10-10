#!/usr/bin/env bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

clear
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}        Update Package Lists           ${NC}"
echo -e "${BLUE}=======================================${NC}\n"

echo -e "Update ${GREEN}pacman.txt${NC} & ${GREEN}yay.txt${NC} in HyprVibe?\n"
echo -e "Press [Y/y] to continue, any other key to abort."
read -r -n 1 response
echo -e "\n"

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo -e "${RED}Aborted.${NC}\n"
    read -p "Press Enter to close..."
    exit 0
fi

echo -e "${BLUE}Running pacman queries...${NC}\n"

# Paths
PACMAN_TXT="$HOME/HyprVibe/packages/pacman.txt"
YAY_TXT="$HOME/HyprVibe/packages/yay.txt"

# Run commands
if pacman -Qneq > "$PACMAN_TXT" && pacman -Qmeq > "$YAY_TXT"; then
    echo -e "${GREEN}Success! Lines written:${NC}\n"
    wc -l "$PACMAN_TXT" "$YAY_TXT"
    echo ""
else
    echo -e "${RED}Failed to update package lists.${NC}\n"
fi

read -p "Press Enter to close..."
