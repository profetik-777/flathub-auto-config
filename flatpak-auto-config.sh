#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

########################################
# 1. Detect distro
########################################
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  OS_ID=$ID
else
  echo "❌ Cannot detect OS; /etc/os-release missing."
  exit 1
fi
echo "📦 Detected OS: $OS_ID $VERSION_ID"

########################################
# 2. Install Flatpak if needed
########################################
install_flatpak() {
  case "$OS_ID" in
    ubuntu|debian)
      sudo apt update
      sudo apt install -y flatpak
      ;;
    fedora)
      sudo dnf -y install flatpak
      ;;
    centos|rhel)
      sudo yum -y install epel-release
      sudo yum -y install flatpak
      ;;
    arch)
      sudo pacman -Sy --noconfirm flatpak
      ;;
    opensuse*|suse)
      sudo zypper --non-interactive install flatpak
      ;;
    *)
      echo "❌ Unsupported OS: $OS_ID"
      exit 1
      ;;
  esac
}

if ! command -v flatpak &>/dev/null; then
  echo "🔧 Installing Flatpak…"
  install_flatpak
else
  echo "✅ Flatpak already present."
fi

########################################
# 3. Ensure user-level Flathub remote
########################################
if ! flatpak remote-list --user --columns=name | grep -qx flathub; then
  echo "🔗 Adding Flathub user remote…"
  flatpak remote-add --user --if-not-exists \
    flathub https://flathub.org/repo/flathub.flatpakrepo
else
  echo "✅ Flathub user remote already configured."
fi

########################################
# 4. Fetch AppStream so `flatpak search` works NOW
########################################
echo "🔄 Downloading Flathub metadata… (this can take 15-30 s)"
flatpak --user update --appstream --noninteractive

########################################
# 5. Default all future installs to user scope
########################################
# 5a) Flatpak native setting (respects GUI installers too)
## this gave an error so removed this: flatpak --user config --set installation user-default true

# 5b) Helpful shell alias for manual CLI typing
PROFILE="${HOME}/.bashrc"      # change to .zshrc if you use zsh
ALIAS="alias flatpak='flatpak --user'"
grep -Fqx "$ALIAS" "$PROFILE" 2>/dev/null || {
  echo "$ALIAS" >> "$PROFILE"
  echo "👤 Added alias to $PROFILE  (run 'source $PROFILE' or open a new shell)"
}

########################################
# 6. Optional: install GUI plugin (Ubuntu GNOME / KDE)
########################################
if command -v gnome-shell &>/dev/null && \
   ! dpkg -s gnome-software-plugin-flatpak &>/dev/null; then
  echo "🖥 Installing GNOME Software Flatpak plugin…"
  sudo apt install -y gnome-software-plugin-flatpak
elif command -v plasmashell &>/dev/null && \
     ! dpkg -s plasma-discover-backend-flatpak &>/dev/null; then
  echo "🖥 Installing KDE Discover Flatpak backend…"
  sudo apt install -y plasma-discover-backend-flatpak
fi

echo -e "\n🎉  All done!  Try:\n    flatpak search firefox\n"

