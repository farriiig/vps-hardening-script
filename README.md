# VPS Hardening Script for Ubuntu/Debian

A clean, interactive Bash script to harden a fresh VPS with safer SSH settings, firewall rules, optional Fail2ban, automatic security updates, and basic sysctl tuning.

Designed for **Ubuntu/Debian** servers and focused on reducing the risk of accidental SSH lockout during setup.

---

## Features

- Interactive step-by-step setup
- Creates or reuses a sudo admin user
- Installs your SSH public key safely
- Changes SSH port
- Optionally disables:
  - root SSH login
  - password-based SSH login
- Configures UFW firewall
- Optionally installs and configures Fail2ban
- Optionally enables unattended security updates
- Optionally applies basic sysctl hardening
- Supports opening extra TCP/UDP ports
- Can open the `3x-ui` panel port during setup
- Includes post-checks after applying changes

---

## Supported Systems

- Ubuntu
- Debian

---

## Important Warning

Before closing your current SSH session, always test login from a new terminal:
```bash
ssh -p YOUR_NEW_PORT YOUR_ADMIN_USER@YOUR_SERVER_IP
