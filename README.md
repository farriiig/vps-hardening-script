# 🛡️ Ultimate VPS Hardening Script

![Ubuntu](https://img.shields.io/badge/Ubuntu-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Debian](https://img.shields.io/badge/Debian-D70A53?style=for-the-badge&logo=debian&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)

یک اسکریپت تعاملی (Interactive) و هوشمند برای امن‌سازی سرورهای اوبونتو و دبیان. این ابزار تمام مراحل خسته‌کننده هاردنینگ را به یک فرآیند ساده و لذت‌بخش تبدیل می‌کند. ✨

---

## 🌟 قابلیت‌های کلیدی (Features)

- **🛠️ کاملاً تعاملی:** پرسش و پاسخ مرحله‌به‌مرحله برای تنظیمات اختصاصی.
- **👤 مدیریت کاربر:** ایجاد کاربر `sudo` جدید و غیرفعال‌سازی دسترسی مستقیم `root`.
- **🔑 امنیت SSH:** نصب خودکار کلید عمومی (SSH Key) و تغییر پورت پیش‌فرض.
- **🔥 فایروال هوشمند:** پیکربندی `UFW` با قابلیت باز کردن پورت‌های اختصاصی و پنل `3x-ui`.
- **🚫 ضد نفوذ:** نصب و تنظیم `Fail2ban` برای جلوگیری از حملات Brute-force.
- **🔄 آپدیت خودکار:** فعال‌سازی `Unattended-upgrades` برای دریافت وصله‌های امنیتی.
- **⚙️ بهینه‌سازی هسته:** اعمال تنظیمات `sysctl` جهت مقاوم‌سازی شبکه در برابر حملات.
- **🎨 ظاهر زیبا:** خروجی رنگی و دسته‌بندی شده برای تجربه کاربری بهتر.

---

## 🚀 شروع سریع (Quick Start)

برای اجرای اسکریپت، کافیست دستورات زیر را به ترتیب در ترمینال خود وارد کنید:

### ۱. ساخت فایل اسکریپت
```bash
nano harden.sh
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
