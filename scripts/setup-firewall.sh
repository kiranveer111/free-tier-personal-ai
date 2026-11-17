#!/usr/bin/env bash
# ==============================================================================
# Oracle Cloud Personal AI Server - Host Firewall & Security Hardening
# ==============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================================${NC}"
echo -e "${BLUE}  Configuring Host Firewall (iptables / UFW) + Fail2ban        ${NC}"
echo -e "${BLUE}================================================================${NC}"

if [ "$EUID" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

echo -e "${YELLOW}Step 1: Installing Fail2ban and persistence packages...${NC}"
$SUDO apt-get update -y
$SUDO apt-get install -y fail2ban iptables-persistent netfilter-persistent

echo -e "${YELLOW}Step 2: Checking and configuring iptables rules for Oracle Cloud...${NC}"
# Allow established traffic
$SUDO iptables -C INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
    $SUDO iptables -I INPUT 1 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Allow loopback
$SUDO iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || \
    $SUDO iptables -I INPUT 2 -i lo -j ACCEPT

# Allow SSH (Port 22)
$SUDO iptables -C INPUT -p tcp --dport 22 -m state --state NEW -j ACCEPT 2>/dev/null || \
    $SUDO iptables -I INPUT 3 -p tcp --dport 22 -m state --state NEW -j ACCEPT

# Allow HTTP (Port 80)
$SUDO iptables -C INPUT -p tcp --dport 80 -m state --state NEW -j ACCEPT 2>/dev/null || \
    $SUDO iptables -I INPUT 4 -p tcp --dport 80 -m state --state NEW -j ACCEPT

# Allow HTTPS (Port 443 TCP & UDP for HTTP/3)
$SUDO iptables -C INPUT -p tcp --dport 443 -m state --state NEW -j ACCEPT 2>/dev/null || \
    $SUDO iptables -I INPUT 5 -p tcp --dport 443 -m state --state NEW -j ACCEPT

$SUDO iptables -C INPUT -p udp --dport 443 -m state --state NEW -j ACCEPT 2>/dev/null || \
    $SUDO iptables -I INPUT 6 -p udp --dport 443 -m state --state NEW -j ACCEPT

echo -e "${YELLOW}Step 3: Ensuring Oracle Cloud iptables FORWARD rule does not block Docker...${NC}"
# Oracle's default image adds "REJECT all -- 0.0.0.0/0 0.0.0.0/0 reject-with icmp-host-prohibited" in FORWARD chain.
# Docker containers need to forward packets through bridge networks.
while $SUDO iptables -D FORWARD -j REJECT --reject-with icmp-host-prohibited 2>/dev/null; do
    echo "Removed legacy Oracle Cloud icmp-host-prohibited FORWARD rejection rule."
done

echo -e "${YELLOW}Step 4: Persisting iptables rules...${NC}"
$SUDO netfilter-persistent save

echo -e "${YELLOW}Step 5: Configuring and starting Fail2ban for SSH...${NC}"
$SUDO cp -n /etc/fail2ban/jail.conf /etc/fail2ban/jail.local 2>/dev/null || true
cat <<EOF | $SUDO tee /etc/fail2ban/jail.d/ssh-docker.local > /dev/null
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 1h
findtime = 10m
EOF

$SUDO systemctl enable fail2ban
$SUDO systemctl restart fail2ban
echo -e "${GREEN}Fail2ban active and monitoring SSH.${NC}"

echo -e "\n${BLUE}================================================================${NC}"
echo -e "${GREEN}Host firewall & security configuration complete!${NC}"
echo -e "${YELLOW}Summary of Open Ports:${NC}"
echo -e "  - TCP Port 22  (SSH Administration)"
echo -e "  - TCP Port 80  (HTTP / Caddy ACME Challenge)"
echo -e "  - TCP Port 443 (HTTPS / Caddy WebUI)"
echo -e "  - UDP Port 443 (HTTP/3 QUIC)"
echo -e "  - All internal ports (11434, 8080, 6333) remain isolated inside Docker."
echo -e "${BLUE}================================================================${NC}"
