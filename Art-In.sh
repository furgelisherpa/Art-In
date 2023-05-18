# part 1
printf '\033c'

# Creating filesystem
read -p "Drive: " drive
cfdisk $drive && lsblk
read -p "boot: " boot
mkfs.fat -F 32 $boot
read -p "root: " root; mkfs.ext4 $root
mount $root /mnt && mkdir -p /mnt/{boot,home}
read -p "home: " home; mkfs.ext4 $home
mount $boot /mnt/boot
mount $home /mnt/home
read -p "Did you create Swap? [y/n]: " checkswap
[ $checkswap = 'y' ] && read -p "SWAP: " swap && mkswap $swap && swapon $swap || continue

# Installing base packages
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf
pacman --noconfirm -Sy artix-keyring
basestrap /mnt base base-devel openrc elogind elogind-openrc linux-zen linux-firmware grub

# Run chroot
fstabgen -U /mnt >> /mnt/etc/fstab
sed '1,/^# part 2$/d' `basename $0` > /mnt/root/part-02.sh
artix-chroot /mnt /bin/bash -c 'sh /root/part-02.sh' && rm -rf /mnt/root/part-02.sh
exit

# part 2
printf '\033c'

# Ask for some info
read -p "hostname: " hostname
read -p "Drive for grub: " drive
printf "\nPassword for root\n" && passwd root

# UserName stuff
printf "\nusername and password\n"
echo -n "user: "; read name
useradd -m -g wheel "$name" >/dev/null 2>&1 || \
    usermod -a -G wheel "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
passwd "$name"
curl https://gist.githubusercontent.com/furgelisherpa/48e42f27631f69015abe4c2a6d28ee59/raw/9a37b50d19d0bff3a0fd7d971e4648cc04089bbb/.bashrc >/root/.bashrc
sudo -u "$name" mkdir -p /home/$name/{\.cache/zsh,dox,hdd,dl,pix,vids,dox,stuff,music}
echo "%wheel ALL=(ALL:ALL) ALL" >/etc/sudoers.d/sudo-for-wheel
echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/poweroff,/usr/bin/reboot" >/etc/sudoers.d/sudo-without-passwd

# Timezone
ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
hwclock --systohc

# Localization
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >> /etc/locale.conf
echo "LC_COLLATE=C" >> /etc/locale.conf
echo "KEYMAP=us" >> /etc/vconsole.conf

# Network configuration
echo "127.0.0.1        localhost" >> /etc/hosts
echo "::1              localhost" >> /etc/hosts
echo "127.0.1.1        $hostname.localdomain  $hostname" >> /etc/hosts
rm -rf /etc/conf.d/hostname && \
    echo "hostname='$hostname'" >/etc/conf.d/hostname

# Try and restart service in parallel
sed -i 's/^#rc_parallel=\"NO\"/rc_parallel=\"YES\"/g' /etc/rc.conf

# Enabling colors and parallel downloads
sed -i "s/^#Color$/Color/" /etc/pacman.conf
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf

# Archlinux-support
echo "
[universe]
Server = https://universe.artixlinux.org/\$arch
Server = https://mirror1.artixlinux.org/universe/\$arch
Server = https://mirror.pascalpuffke.de/artix-universe/\$arch
Server = https://artixlinux.qontinuum.space/artixlinux/universe/os/\$arch
Server = https://mirror1.cl.netactuate.com/artix/universe/\$arch
Server = https://ftp.crifo.org/artix-universe/" >> /etc/pacman.conf && pacman -Sy

pacman --noconfirm --needed -S \
  artix-keyring artix-archlinux-support

for repo in extra community; do
  grep -q "^\[$repo\]" /etc/pacman.conf ||
    echo "
[$repo]
Include = /etc/pacman.d/mirrorlist-arch" >> /etc/pacman.conf
done
pacman -Sy && pacman-key --populate archlinux

# packages
pacman --noconfirm -S xorg-server xorg-xinit xf86-video-intel xcompmgr xorg-xprop xorg-xdpyinfo xorg-xrandr xcape xclip xdotool xdg-user-dirs xwallpaper \
  pulsemixer pamixer pipewire pipewire-alsa pipewire-pulse wireplumber mpc mpv ffmpeg mpd  \
  libnotify dunst neovim man-db newsboat sox sxhkd arch-wiki-docs materia-gtk-theme papirus-icon-theme \
  maim unclutter unzip yt-dlp zathura zathura-pdf-mupdf skim socat moreutils poppler python-pip python-pywal firefox-esr zsh git transmission-cli \
  noto-fonts-emoji ttf-jetbrains-mono ttf-linux-libertine ttf-nerd-fonts-symbols-2048-em ttf-joypixels ttf-inconsolata \
  ntp ntp-openrc acpid acpid-openrc syslog-ng syslog-ng-openrc networkmanager networkmanager-openrc network-manager-applet cronie cronie-openrc \
  gnome-keyring polkit-gnome imagemagick jq ncmpcpp rsync screenkey slock pinentry pass passmenu

# Dotfiles
printf "\nGetting dotfiles\n"
dir=$(mktemp -d) && chown "$name":wheel $dir
sudo -u "$name" git -C "$dir" clone --depth 1 https://github.com/furgelisherpa/dotfiles
shopt -s dotglob
sudo -u $name cp -r $dir/dotfiles/* /home/$name/ && rm -rf /home/$name/.bash* /home/$name/.git

# Suckless tools
repodir="/home/$name/.local/src" && sudo -u $name mkdir -p $repodir
printf "\nGetting Suckless tools\n"
sudo -u "$name" git -C "$repodir" clone --depth 1 https://github.com/furgelisherpa/dwm
sudo make -C "$repodir"/dwm install
sudo -u "$name" git -C "$repodir" clone https://github.com/furgelisherpa/st
sudo make -C "$repodir"/st install
sudo -u "$name" git -C "$repodir" clone https://github.com/furgelisherpa/dwmblocks
sudo make -C "$repodir"/dwmblocks install
sudo -u "$name" git -C "$repodir" clone https://github.com/furgelisherpa/dmenu
sudo make -C "$repodir"/dmenu install

# YAY packages
printf "\nClonning YAY the AUR helper\n"
sudo -u "$name" git -C "$repodir" clone --depth 1 https://aur.archlinux.org/yay
printf "\nBuilding YAY \n"
cd "$repodir"/yay && sudo -u $name makepkg -fsri
printf "\nInstalling packages from Aur\n "
sudo -u $name yay -S python-pywalfox tremc downgrade pfetch zsh-fast-syntax-highlighting-git abook nsxiv pinentry-dmenu pam-gnupg

# Default shell
printf "\nChanging default shell to zsh\n"
chsh -s /bin/zsh $name
# Getting wallpaper
sudo -u "$name" git clone --depth 1 https://github.com/furgelisherpa/wal.git /home/$name/pix/wal && rm -rf /home/$name/pix/wal/.git

# Installing bootloader
grub-install --recheck $drive
sed -i -e 's/^GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g' \
    -e 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Adding stuff to the runlevel
rc-update add NetworkManager default
rc-update add ntpd default
rc-update add acpid default
rc-update add cronie default
rc-update add syslog-ng default
exit
