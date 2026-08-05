#!/usr/bin/env bash
#
# arch-bootstrap.sh
# Run this from the Arch Linux live ISO environment (as root).
#
# Does:
#   - Destructively partitions a chosen disk
#   - ext4 root (+ ESP if UEFI), auto-detected boot mode, GRUB
#   - Optional LUKS2 full-disk encryption (prompted)
#   - i3 minimal WM, zram swap, NetworkManager
#   - Wireless networking tools (iwd) for post-install Wi-Fi
#   - Prompts for hostname / user / password / timezone / locale
#
# Does NOT:
#   - Handle dual boot, RAID, or multi-disk layouts
#
set -euo pipefail

# ---------- helpers ----------

log() { printf '\n\033[1;32m==>\033[0m %s\n' "$1"; }
die() { printf '\n\033[1;31m!!\033[0m %s\n' "$1" >&2; exit 1; }

ask() {
  local prompt="$1" default="${2:-}" reply
  read -rp "${prompt}${default:+ [$default]}: " reply
  echo "${reply:-$default}"
}

ask_yn() {
  local prompt="$1" default="${2:-n}" reply
  read -rp "${prompt} [y/N]: " reply
  reply="${reply:-$default}"
  [[ "${reply,,}" == y* ]]
}

# Return the Nth partition device path for a given disk.
# nvme/mmc devices use a 'p' separator (e.g. /dev/nvme0n1p1), others don't.
part_dev() {
  local disk="$1" num="$2"
  if [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]]; then
    echo "${disk}p${num}"
  else
    echo "${disk}${num}"
  fi
}

# ---------- pre-flight checks ----------

[[ $EUID -eq 0 ]] || die "Run this as root from the Arch ISO."

if [[ -d /sys/firmware/efi/efivars ]]; then
  BOOT_MODE="uefi"
else
  BOOT_MODE="bios"
fi
log "Detected boot mode: $BOOT_MODE"

ping -c1 -W2 archlinux.org &>/dev/null \
  || die "No network connectivity. Connect first (iwctl / dhcpcd) and retry."

timedatectl set-ntp true

# ---------- gather input ----------

log "Available block devices:"
lsblk -dpno NAME,SIZE,MODEL | grep -v loop

TARGET_DISK=$(ask "Target disk (e.g. /dev/sda or /dev/nvme0n1)")
[[ -b "$TARGET_DISK" ]] || die "No such block device: $TARGET_DISK"

echo
echo "!! WARNING !! This will ERASE ALL DATA on $TARGET_DISK"
CONFIRM=$(ask "Type the disk path again to confirm")
[[ "$CONFIRM" == "$TARGET_DISK" ]] || die "Confirmation did not match. Aborting."

# -- encryption --
USE_LUKS="no"
if ask_yn "Enable LUKS2 full-disk encryption?"; then
  USE_LUKS="yes"
  echo
  echo "You can use the same password as your login, or a separate disk passphrase."
  while true; do
    read -rsp "LUKS passphrase: " LUKS_PASS; echo
    read -rsp "Confirm LUKS passphrase: " LUKS_PASS2; echo
    [[ "$LUKS_PASS" == "$LUKS_PASS2" && -n "$LUKS_PASS" ]] && break
    echo "Passphrases didn't match or were empty, try again."
  done
fi

HOSTNAME=$(ask "Hostname" "archbox")
USERNAME=$(ask "Username to create" "arch")

while true; do
  read -rsp "Password for $USERNAME (and root): " PASSWORD; echo
  read -rsp "Confirm password: " PASSWORD2; echo
  [[ "$PASSWORD" == "$PASSWORD2" && -n "$PASSWORD" ]] && break
  echo "Passwords didn't match or were empty, try again."
done

TIMEZONE=$(ask "Timezone" "UTC")
LOCALE=$(ask "Locale" "en_US.UTF-8")
KEYMAP=$(ask "Console keymap" "us")

# ---------- partitioning ----------

log "Partitioning $TARGET_DISK for $BOOT_MODE boot..."

wipefs -af "$TARGET_DISK"

if [[ "$BOOT_MODE" == "uefi" ]]; then
  parted -s "$TARGET_DISK" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 513MiB \
    set 1 esp on \
    mkpart primary ext4 513MiB 100%
  ESP_PART=$(part_dev "$TARGET_DISK" 1)
  ROOT_PART=$(part_dev "$TARGET_DISK" 2)
else
  parted -s "$TARGET_DISK" \
    mklabel msdos \
    mkpart primary ext4 1MiB 100% \
    set 1 boot on
  ROOT_PART=$(part_dev "$TARGET_DISK" 1)
fi

partprobe "$TARGET_DISK"
sleep 2  # let the kernel finish re-reading the partition table

# ---------- LUKS encryption (optional) ----------

LUKS_UUID=""
if [[ "$USE_LUKS" == "yes" ]]; then
  log "Setting up LUKS2 encryption on $ROOT_PART..."
  LUKS_EXTRA_ARGS=()
  if [[ "$BOOT_MODE" == "bios" ]]; then
    # In BIOS mode /boot lives inside the encrypted root, so GRUB itself must
    # unlock the LUKS volume.  GRUB 2.12 only supports PBKDF2 (not Argon2id).
    LUKS_EXTRA_ARGS=(--pbkdf pbkdf2)
  fi
  printf '%s' "$LUKS_PASS" | cryptsetup luksFormat --type luks2 \
    --cipher aes-xts-plain64 --key-size 512 --hash sha256 \
    --iter-time 5000 --batch-mode "${LUKS_EXTRA_ARGS[@]}" "$ROOT_PART" -

  printf '%s' "$LUKS_PASS" | cryptsetup open "$ROOT_PART" cryptroot -

  LUKS_UUID=$(cryptsetup luksUUID "$ROOT_PART")
  # From here on, the "root device" is the opened mapper device
  ROOT_PART="/dev/mapper/cryptroot"
fi

# ---------- formatting ----------

log "Formatting..."
mkfs.ext4 -F "$ROOT_PART"
mount "$ROOT_PART" /mnt

if [[ "$BOOT_MODE" == "uefi" ]]; then
  mkfs.fat -F32 "$ESP_PART"
  mkdir -p /mnt/boot
  mount "$ESP_PART" /mnt/boot
fi

# ---------- base install ----------

log "Installing base system (this takes a while)..."
PACKAGES=(
  base base-devel linux linux-firmware
  networkmanager
  iwd                    # Wi-Fi backend (iwctl); NetworkManager can use it
  wireless_tools         # iwconfig and friends
  wpa_supplicant         # fallback WPA support
  sudo vim git curl
  grub
  xorg-server xorg-xinit
  i3-wm i3status i3lock dmenu
  alacritty
  zram-generator
)
[[ "$BOOT_MODE" == "uefi" ]] && PACKAGES+=(efibootmgr)

pacstrap -K /mnt "${PACKAGES[@]}"

log "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# ---------- chroot configuration ----------

# Write the password to a temporary file so the heredoc can be single-quoted
# (no risk of shell metacharacters in the password breaking expansion).
PASS_FILE=/mnt/root/.install-pw
printf '%s' "$PASSWORD" > "$PASS_FILE"
chmod 600 "$PASS_FILE"

log "Entering chroot..."

# Single-quoted heredoc delimiter prevents variable expansion — all values are
# passed as explicit environment variables via arch-chroot's env.
arch-chroot /mnt /usr/bin/env \
  TIMEZONE="$TIMEZONE" \
  LOCALE="$LOCALE" \
  KEYMAP="$KEYMAP" \
  HOSTNAME_="$HOSTNAME" \
  USERNAME="$USERNAME" \
  BOOT_MODE="$BOOT_MODE" \
  TARGET_DISK="$TARGET_DISK" \
  USE_LUKS="$USE_LUKS" \
  LUKS_UUID="$LUKS_UUID" \
  bash -s <<'CHROOT_EOF'
set -euo pipefail

# -- timezone / clock --
ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc

# -- locale --
sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# -- hostname / hosts --
echo "${HOSTNAME_}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME_}.localdomain ${HOSTNAME_}
EOF

# -- users --
PW=$(cat /root/.install-pw)
echo "root:${PW}" | chpasswd
useradd -m -G wheel -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${PW}" | chpasswd
rm -f /root/.install-pw
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# -- initramfs (LUKS needs the 'encrypt' hook) --
if [[ "${USE_LUKS}" == "yes" ]]; then
  # Current default HOOKS (mkinitcpio ≥38):
  #   HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
  #
  # For LUKS we need 'encrypt' between 'block' and 'filesystems'.  The
  # required ordering is: keyboard → keymap → block → encrypt → filesystems.
  # keyboard/keymap/block are already present in the defaults, so we just
  # splice 'encrypt' in front of 'filesystems'.
  sed -i 's/^\(HOOKS=(.*\) filesystems/\1 encrypt filesystems/' /etc/mkinitcpio.conf
fi
mkinitcpio -P

# -- bootloader --
if [[ "${USE_LUKS}" == "yes" ]]; then
  # Tell the initramfs 'encrypt' hook how to unlock the root partition
  sed -i "s|^GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${LUKS_UUID}:cryptroot root=/dev/mapper/cryptroot\"|" /etc/default/grub
  if [[ "${BOOT_MODE}" == "bios" ]]; then
    # BIOS: /boot is inside the encrypted root, so GRUB must unlock LUKS
    echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub
  fi
fi

if [[ "${BOOT_MODE}" == "uefi" ]]; then
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
  grub-install --target=i386-pc "${TARGET_DISK}"
fi
grub-mkconfig -o /boot/grub/grub.cfg

# -- zram swap (no swap partition/file) --
cat > /etc/systemd/zram-generator.conf <<ZRAM
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
ZRAM

# -- services --
systemctl enable NetworkManager
systemctl enable iwd   # Wi-Fi backend — available immediately after boot

# -- configure NetworkManager to use iwd as its Wi-Fi backend --
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/wifi-backend.conf <<NMCONF
[device]
wifi.backend=iwd
NMCONF

# -- minimal .xinitrc so 'startx' launches i3 --
cat > "/home/${USERNAME}/.xinitrc" <<XINIT
exec i3
XINIT
chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.xinitrc"
CHROOT_EOF

# Clean up in case chroot failed before removing it
rm -f /mnt/root/.install-pw

log "Done. Unmount and reboot when ready:"
if [[ "$USE_LUKS" == "yes" ]]; then
  echo "    umount -R /mnt"
  echo "    cryptsetup close cryptroot"
  echo "    reboot"
  echo
  echo "You will be prompted for your LUKS passphrase on every boot."
else
  echo "    umount -R /mnt"
  echo "    reboot"
fi
echo
echo "After first login, run 'startx' to launch i3."
echo "Wi-Fi: use 'nmcli' or 'iwctl' to connect to wireless networks."
