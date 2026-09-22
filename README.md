# ![GitHub Downloads (all assets, all releases)](https://img.shields.io/github/downloads/minios-linux/minios-live/total?style=for-the-badge&logoSize=30&label=%20TOTAL%20DOWNLOADS&labelColor=white&color=orange)

<img width="1280" height="800" alt="MiniOS Standard" src="https://github.com/user-attachments/assets/e1026126-1a33-4a62-9122-f1ac4d23399d" />

MiniOS is a reliable and user-friendly portable system with a graphical interface. These scripts build a bootable MiniOS ISO image.

## 🌐 Resources

Learn more about using and building MiniOS:

### 🖥️ Official Website

The [official website](https://minios.dev) is your central hub for information about MiniOS.  Find details on the different editions available, their respective features, community forums for support, and direct download links for the ISO images.

### 📚 Official Wiki

The [official Wiki](https://github.com/minios-linux/minios-live/wiki) provides in-depth knowledge and practical guidance for working with MiniOS. Explore comprehensive guides covering installation procedures, system configuration, customization options, and how to extend functionality with modules.

### 🚀 Quick Start Guide

New to MiniOS? Start with our comprehensive [Quick Start Guide](https://github.com/minios-linux/minios-live/wiki/Quick-Start) that covers everything from choosing the right edition to setting up security and customizing your system. Perfect for beginners and experienced users alike.

**Note:**

* For information on building MiniOS and modifying modules, read the [Building MiniOS Guide](https://github.com/minios-linux/minios-live/wiki/Building-MiniOS).

## ✍️ Authors

MiniOS was created by:
- [crims0n](https://github.com/crim50n) - the original author and maintainer of MiniOS
- [.nemesis](https://github.com/zukhovich) - designer and developer of the MiniOS graphical interface
- [FershoUno](https://github.com/fershouno) - tester and contributor to the MiniOS project
- [sfs-pra](https://github.com/sfs-pra) - developer of the PuppyRus Linux and contributor to the MiniOS project
- [betcher](https://github.com/betcher) - developer of the ROSA Barium and contributor to the MiniOS project
- [gumanzoy](https://github.com/gumanzoy) - developer of the PocketHandyBox and contributor to the MiniOS project
- [xDoofy92](https://github.com/xDoofy92) - media support for the MiniOS project

## 🔀 About This Fork

This fork builds MiniOS on Debian 14 (forky) with the KDE Plasma desktop and ships the Apx container-based package manager alongside it. It keeps everything that makes MiniOS what it is — a portable, live-bootable system that runs from a USB stick and remembers your changes — and pairs it with a full-featured desktop and a way to install software from other Linux distributions without touching the base system.

What you get:

- **A current Debian base.** Built on Debian 14, so the kernel, drivers and applications are recent.
- **KDE Plasma.** A complete, polished desktop with the MiniOS look, booting straight to the desktop as a live user.
- **Apx.** Install packages from Debian, Fedora, Arch, Alpine and others in isolated containers; they show up as ordinary applications while the live system stays clean.
- **MiniOS tooling.** The installer, module manager, store, kernel manager and the rest of the MiniOS utilities are all present.

Upstream MiniOS remains the reference project; this fork tracks it and only adds what is described above.
