#!/bin/bash
# =============================================================================
# Server Hardening Script for Ubuntu 22.04 LTS
# =============================================================================
# 
# Description: Comprehensive security hardening for EC2 instances
# Usage:        sudo ./server-hardening.sh
# 
# WARNING:      Run this script ONLY after verifying SSM access works! 
#              Some changes may lock you out if SSM is not configured. 
#
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log file
LOG_FILE="/var/log/server-hardening. log"
BACKUP_DIR="/root/hardening-backup-$(date +%Y%m%d-%H%M%S)"

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
    echo "[WARNING] $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    echo "[ERROR] $1" >> "$LOG_FILE"
}

section() {
    echo ""
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
}

backup_file() {
    if [ -f "$1" ]; then
        cp "$1" "$BACKUP_DIR/$(basename $1).bak"
        log "Backed up:  $1"
    fi
}

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

preflight_checks() {
    section "PRE-FLIGHT CHECKS"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root (use sudo)"
        exit 1
    fi
    log "✅ Running as root"
    
    # Check Ubuntu version
    if !  grep -q "Ubuntu" /etc/os-release; then
        error "This script is designed for Ubuntu"
        exit 1
    fi
    log "✅ Ubuntu detected"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    log "✅ Backup directory created:  $BACKUP_DIR"
    
    # Check internet connectivity
    if !  ping -c 1 google.com &> /dev/null; then
        warn "No internet connectivity - some updates may fail"
    else
        log "✅ Internet connectivity OK"
    fi
}

# =============================================================================
# 1. SYSTEM UPDATES
# =============================================================================

system_updates() {
    section "1. SYSTEM UPDATES"
    
    log "Updating package lists..."
    apt update -y
    
    log "Upgrading packages..."
    DEBIAN_FRONTEND=noninteractive apt upgrade -y
    
    log "Installing security updates..."
    DEBIAN_FRONTEND=noninteractive apt install -y unattended-upgrades
    
    log "Removing unnecessary packages..."
    apt autoremove -y
    apt autoclean -y
    
    log "✅ System updates complete"
}

# =============================================================================
# 2. USER SECURITY
# =============================================================================

user_security() {
    section "2. USER SECURITY"
    
    # Backup files
    backup_file "/etc/login.defs"
    backup_file "/etc/security/pwquality.conf"
    
    # Set password policies
    log "Configuring password policies..."
    
    # Password aging
    sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' /etc/login.defs
    sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   1/' /etc/login.defs
    sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   7/' /etc/login.defs
    
    # Install password quality checker
    apt install -y libpam-pwquality
    
    # Configure password quality
    cat > /etc/security/pwquality.conf << 'EOF'
# Password quality configuration
minlen = 12
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
maxrepeat = 3
reject_username
enforce_for_root
EOF
    
    # Lock root account (use sudo instead)
    log "Securing root account..."
    passwd -l root 2>/dev/null || true
    
    # Ensure sudo is configured properly
    log "Configuring sudo..."
    if ! grep -q "Defaults logfile" /etc/sudoers; then
        echo 'Defaults logfile="/var/log/sudo.log"' >> /etc/sudoers
    fi
    
    log "✅ User security configured"
}

# =============================================================================
# 3. SSH HARDENING
# =============================================================================

ssh_hardening() {
    section "3. SSH HARDENING"
    
    backup_file "/etc/ssh/sshd_config"
    
    log "Hardening SSH configuration..."
    
    # Create hardened SSH config
    cat > /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
# =============================================================================
# SSH Hardening Configuration
# =============================================================================

# Disable root login
PermitRootLogin no

# Disable password authentication (use keys only)
PasswordAuthentication no
PermitEmptyPasswords no

# Disable challenge-response authentication
ChallengeResponseAuthentication no

# Use only SSH Protocol 2
Protocol 2

# Limit authentication attempts
MaxAuthTries 3

# Set login grace time
LoginGraceTime 30

# Disable X11 forwarding
X11Forwarding no

# Disable TCP forwarding
AllowTcpForwarding no

# Disable agent forwarding
AllowAgentForwarding no

# Set client alive settings
ClientAliveInterval 300
ClientAliveCountMax 2

# Disable unused authentication methods
HostbasedAuthentication no
IgnoreRhosts yes

# Log level
LogLevel VERBOSE

# Disable GSSAPI
GSSAPIAuthentication no

# Restrict ciphers to strong ones
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# Restrict MACs
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

# Restrict key exchange algorithms
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
EOF
    
    # Test SSH config
    if sshd -t; then
        log "SSH configuration valid"
        systemctl reload sshd
        log "✅ SSH hardening complete"
    else
        error "SSH configuration invalid - reverting"
        rm /etc/ssh/sshd_config.d/hardening.conf
        exit 1
    fi
}

# =============================================================================
# 4. NETWORK SECURITY
# =============================================================================

network_security() {
    section "4. NETWORK SECURITY"
    
    backup_file "/etc/sysctl.conf"
    
    log "Configuring kernel network security..."
    
    # Create sysctl hardening config
    cat > /etc/sysctl.d/99-hardening.conf << 'EOF'
# =============================================================================
# Kernel Network Security Hardening
# =============================================================================

# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Block SYN attacks
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore Directed pings
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Disable IPv6 if not needed (uncomment if not using IPv6)
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf. default.disable_ipv6 = 1

# Increase system file descriptor limit
fs.file-max = 65535

# Allow for more PIDs
kernel.pid_max = 65536

# Increase system IP port limits
net.ipv4.ip_local_port_range = 2000 65000

# TCP memory tuning
net.ipv4.tcp_rmem = 4096 87380 8388608
net.ipv4.tcp_wmem = 4096 87380 8388608

# Disable core dumps
fs.suid_dumpable = 0

# Restrict kernel pointers
kernel.kptr_restrict = 2

# Restrict dmesg access
kernel.dmesg_restrict = 1
EOF
    
    # Apply sysctl settings
    sysctl -p /etc/sysctl.d/99-hardening.conf
    
    log "✅ Network security configured"
}

# =============================================================================
# 5. FIREWALL (UFW)
# =============================================================================

configure_firewall() {
    section "5. FIREWALL CONFIGURATION"
    
    log "Installing and configuring UFW..."
    
    apt install -y ufw
    
    # Reset UFW
    ufw --force reset
    
    # Set defaults
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow required ports
    ufw allow 22/tcp comment 'SSH - Remove after SSM migration'
    ufw allow 80/tcp comment 'HTTP - Nginx'
    ufw allow 443/tcp comment 'HTTPS - Nginx SSL'
    
    # Enable logging
    ufw logging medium
    
    # Enable UFW
    ufw --force enable
    
    log "✅ Firewall configured"
    ufw status verbose
}

# =============================================================================
# 6. FAIL2BAN (Brute Force Protection)
# =============================================================================

configure_fail2ban() {
    section "6. FAIL2BAN CONFIGURATION"
    
    log "Installing Fail2ban..."
    apt install -y fail2ban
    
    log "Configuring Fail2ban..."
    
    # Create local jail config
    cat > /etc/fail2ban/jail.local << 'EOF'
# =============================================================================
# Fail2ban Configuration
# =============================================================================

[DEFAULT]
# Ban duration (10 minutes)
bantime = 600

# Time window for failures
findtime = 600

# Max failures before ban
maxretry = 5

# Email alerts (optional - configure as needed)
# destemail = admin@example.com
# sendername = Fail2Ban
# mta = sendmail

# Default action
action = %(action_)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[sshd-ddos]
enabled = true
port = ssh
filter = sshd-ddos
logpath = /var/log/auth.log
maxretry = 6
bantime = 3600

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
EOF
    
    # Restart fail2ban
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    log "✅ Fail2ban configured"
    fail2ban-client status
}

# =============================================================================
# 7. AUTOMATIC SECURITY UPDATES
# =============================================================================

configure_auto_updates() {
    section "7. AUTOMATIC SECURITY UPDATES"
    
    log "Configuring automatic security updates..."
    
    apt install -y unattended-upgrades apt-listchanges
    
    # Configure unattended-upgrades
    cat > /etc/apt/apt.conf. d/50unattended-upgrades << 'EOF'
Unattended-Upgrade:: Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::DevRelease "auto";
Unattended-Upgrade:: Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade:: Remove-Unused-Dependencies "true";
Unattended-Upgrade:: Automatic-Reboot "false";
Unattended-Upgrade:: Automatic-Reboot-Time "02:00";

// Logging
Unattended-Upgrade::SyslogEnable "true";
Unattended-Upgrade::SyslogFacility "daemon";
EOF
    
    # Enable auto-updates
    cat > /etc/apt/apt.conf. d/20auto-upgrades << 'EOF'
APT::Periodic:: Update-Package-Lists "1";
APT::Periodic:: Unattended-Upgrade "1";
APT::Periodic:: Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF
    
    # Enable the service
    systemctl enable unattended-upgrades
    systemctl start unattended-upgrades
    
    log "✅ Automatic updates configured"
}

# =============================================================================
# 8. AUDITD (System Auditing)
# =============================================================================

configure_auditd() {
    section "8. SYSTEM AUDITING (AUDITD)"
    
    log "Installing auditd..."
    apt install -y auditd audispd-plugins
    
    log "Configuring audit rules..."
    
    # Create audit rules
    cat > /etc/audit/rules.d/hardening.rules << 'EOF'
# =============================================================================
# Audit Rules for Security Monitoring
# =============================================================================

# Delete all existing rules
-D

# Set buffer size
-b 8192

# Failure mode (1 = printk, 2 = panic)
-f 1

# Monitor user/group changes
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# Monitor sudoers
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers. d/ -p wa -k sudoers

# Monitor SSH configuration
-w /etc/ssh/sshd_config -p wa -k sshd

# Monitor cron
-w /etc/crontab -p wa -k cron
-w /etc/cron.d/ -p wa -k cron
-w /etc/cron.daily/ -p wa -k cron
-w /etc/cron.hourly/ -p wa -k cron
-w /etc/cron.monthly/ -p wa -k cron
-w /etc/cron.weekly/ -p wa -k cron

# Monitor login files
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins

# Monitor network configuration
-w /etc/hosts -p wa -k network
-w /etc/network/ -p wa -k network
-w /etc/sysctl.conf -p wa -k network

# Monitor Docker (if installed)
-w /usr/bin/docker -p wa -k docker
-w /var/lib/docker -p wa -k docker
-w /etc/docker -p wa -k docker

# Monitor system calls for privilege escalation
-a always,exit -F arch=b64 -S execve -k exec
-a always,exit -F arch=b32 -S execve -k exec

# Make rules immutable (requires reboot to change)
-e 2
EOF
    
    # Restart auditd
    systemctl restart auditd
    systemctl enable auditd
    
    log "✅ Auditd configured"
}

# =============================================================================
# 9. FILE PERMISSIONS
# =============================================================================

secure_file_permissions() {
    section "9. FILE PERMISSIONS"
    
    log "Securing file permissions..."
    
    # Secure cron directories
    chmod 700 /etc/cron.d
    chmod 700 /etc/cron.daily
    chmod 700 /etc/cron.hourly
    chmod 700 /etc/cron.weekly
    chmod 700 /etc/cron.monthly
    chmod 600 /etc/crontab
    
    # Secure SSH directory
    chmod 700 /etc/ssh
    chmod 600 /etc/ssh/sshd_config
    
    # Secure passwd/shadow
    chmod 644 /etc/passwd
    chmod 600 /etc/shadow
    chmod 644 /etc/group
    chmod 600 /etc/gshadow
    
    # Remove world-readable permissions from sensitive files
    chmod 600 /etc/security/opasswd 2>/dev/null || true
    
    log "✅ File permissions secured"
}

# =============================================================================
# 10. DISABLE UNUSED SERVICES
# =============================================================================

disable_unused_services() {
    section "10. DISABLE UNUSED SERVICES"
    
    log "Disabling unnecessary services..."
    
    # List of services to disable (if they exist)
    services=(
        "cups"
        "avahi-daemon"
        "bluetooth"
        "isc-dhcp-server"
        "isc-dhcp-server6"
        "rpcbind"
        "nfs-server"
    )
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            systemctl stop "$service"
            systemctl disable "$service"
            log "Disabled: $service"
        fi
    done
    
    log "✅ Unused services disabled"
}

# =============================================================================
# 11. SECURE SHARED MEMORY
# =============================================================================

secure_shared_memory() {
    section "11. SECURE SHARED MEMORY"
    
    backup_file "/etc/fstab"
    
    log "Securing shared memory..."
    
    # Check if already configured
    if !  grep -q "tmpfs /run/shm" /etc/fstab; then
        echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
        log "Added shared memory mount options"
    else
        log "Shared memory already configured"
    fi
    
    log "✅ Shared memory secured"
}

# =============================================================================
# 12. INSTALL SECURITY TOOLS
# =============================================================================

install_security_tools() {
    section "12. SECURITY TOOLS"
    
    log "Installing security tools..."
    
    apt install -y \
        rkhunter \
        chkrootkit \
        lynis \
        clamav \
        clamav-daemon \
        acct \
        sysstat \
        htop
    
    # Update rkhunter database
    rkhunter --update 2>/dev/null || true
    rkhunter --propupd 2>/dev/null || true
    
    # Update ClamAV database
    systemctl stop clamav-freshclam 2>/dev/null || true
    freshclam 2>/dev/null || true
    systemctl start clamav-freshclam 2>/dev/null || true
    
    log "✅ Security tools installed"
}

# =============================================================================
# 13. CREATE SECURITY BANNER
# =============================================================================

create_security_banner() {
    section "13. SECURITY BANNER"
    
    log "Creating security banner..."
    
    cat > /etc/issue.net << 'EOF'
***************************************************************************
                        AUTHORIZED ACCESS ONLY
***************************************************************************

This system is for authorized users only.  All activities are monitored
and logged.  Unauthorized access attempts will be reported to the
appropriate authorities.

By accessing this system, you consent to monitoring and agree to comply
with all applicable policies and laws.

***************************************************************************
EOF
    
    cat > /etc/motd << 'EOF'

=============================================================================
                     ECOMMERCE FRONTEND - PRODUCTION SERVER
=============================================================================

  System:      Ubuntu 22.04 LTS (Hardened)
  Purpose:    E-Commerce Frontend Application
  Monitoring: All activities are logged

  Security:   This server has been hardened according to security best
              practices.  Unauthorized modifications are prohibited.

=============================================================================

EOF
    
    # Enable banner in SSH
    if ! grep -q "^Banner /etc/issue.net" /etc/ssh/sshd_config; then
        echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
    fi
    
    log "✅ Security banner created"
}

# =============================================================================
# SUMMARY & REPORT
# =============================================================================

generate_report() {
    section "HARDENING COMPLETE"
    
    cat << EOF

=============================================================================
                     SERVER HARDENING REPORT
=============================================================================

  Date:        $(date)
  Hostname:   $(hostname)
  IP:          $(hostname -I | awk '{print $1}')
  Backup:      $BACKUP_DIR
  Log:         $LOG_FILE

  COMPLETED TASKS:
  ─────────────────
  ✅ System updates
  ✅ User security (password policies, root locked)
  ✅ SSH hardening (key-only auth, root disabled)
  ✅ Network security (sysctl hardening)
  ✅ Firewall (UFW - ports 22, 80, 443)
  ✅ Fail2ban (brute force protection)
  ✅ Automatic security updates
  ✅ Auditd (system auditing)
  ✅ File permissions secured
  ✅ Unused services disabled
  ✅ Shared memory secured
  ✅ Security tools installed
  ✅ Security banner created

  NEXT STEPS:
  ─────────────────
  1. Verify application still works
  2. Test SSH access
  3. Configure SSM (Stage 7)
  4. Remove SSH after SSM verified
  5. Run security scan:  sudo lynis audit system

  IMPORTANT FILES:
  ─────────────────
  • SSH Config:     /etc/ssh/sshd_config.d/hardening.conf
  • Sysctl:         /etc/sysctl.d/99-hardening.conf
  • Fail2ban:      /etc/fail2ban/jail.local
  • Audit Rules:   /etc/audit/rules.d/hardening.rules
  • UFW Status:    sudo ufw status

  SECURITY SCAN: 
  ─────────────────
  Run: sudo lynis audit system

=============================================================================

EOF
    
    # Save report to file
    cat << EOF > "$BACKUP_DIR/hardening-report.txt"
Server Hardening Report
=======================
Date: $(date)
Hostname: $(hostname)
Backup Directory: $BACKUP_DIR

See $LOG_FILE for detailed logs. 
EOF
    
    log "Report saved to:  $BACKUP_DIR/hardening-report.txt"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    echo ""
    echo "============================================================================="
    echo "               SERVER HARDENING SCRIPT - Ubuntu 22.04 LTS"
    echo "============================================================================="
    echo ""
    echo "  This script will harden your server security configuration."
    echo "  A backup of all modified files will be created."
    echo ""
    echo "  WARNING:  Ensure SSM access works before running this script!"
    echo ""
    echo "============================================================================="
    echo ""
    
    read -p "Do you want to continue?  (y/n): " -n 1 -r
    echo ""
    
    if [[ !  $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
    
    # Execute hardening steps
    preflight_checks
    system_updates
    user_security
    ssh_hardening
    network_security
    configure_firewall
    configure_fail2ban
    configure_auto_updates
    configure_auditd
    secure_file_permissions
    disable_unused_services
    secure_shared_memory
    install_security_tools
    create_security_banner
    generate_report
    
    echo ""
    log "🔒 SERVER HARDENING COMPLETE!"
    echo ""
}

# Run main function
main "$@"