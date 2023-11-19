# part 1
printf '\033c'

# creating filesystem
lsblk && read -p "Drive: " DRIVE
cfdisk $DRIVE && lsblk
read -p "boot: " BOOT
mkfs.fat -F 32 $BOOT
read -p "root: " ROOT; mkfs.ext4 $ROOT
mount $ROOT /mnt && mkdir -p /mnt/{boot/efi,home}
read -p "home: " HOME; mkfs.ext4 $HOME
mount $BOOT /mnt/boot/efi
mount $HOME /mnt/home
read -p "Did you create Swap? [y/n]: " CHECKSWAP
[ $CHECKSWAP = 'y' ] && read -p "SWAP: " SWAP \
  && mkswap $SWAP && swapon $SWAP || continue

# installing base packages
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf
pacman --noconfirm -Sy artix-keyring
basestrap /mnt base openrc elogind elogind-openrc linux-lts linux-firmware grub efibootmgr amd-ucode

# run chroot
fstabgen -U /mnt >/mnt/etc/fstab
sed '1,/^# part 2$/d' `basename $0` >/mnt/root/part-02.sh
artix-chroot /mnt /bin/bash -c 'sh /root/part-02.sh' && rm -rf /mnt/root/part-02.sh
exit

# part 2
printf '\033c'

# ask for some info
read -p "hostname: " HOSTNAME
read -p "Drive for grub: " DRIVE
printf "\nPassword for root\n" && passwd root

# username stuff
printf "\nusername and password\n"
echo -n "user: "; read NAME
useradd -m -g wheel "$NAME" >/dev/null 2>&1 || \
  usermod -a -G wheel "$NAME" && mkdir -p /home/"$NAME";

passwd "$NAME"
echo "permit persist :wheel" >/etc/doas.conf
mkdir -p /home/$NAME/{\.cache/zsh,dox,dl,pix,vids,dox,github,stuff,music}
chown -R "$NAME":wheel /home/"$NAME"

# bashrc for root
echo "alias ls='ls --color=auto'" >/root/.bashrc
echo "PS1='\e[0;31m[\e[0m\e[0;33m\u\e[0m\e[0;32m@\e[0m\e[0;034m\h\e[0m  \e[0;95m\W\e[0m\e[0;31m]\e[0m# '" >> /root/.bashrc

# timezone
ln -sf /usr/share/zoneinfo/Asia/Kathmandu /etc/localtime
hwclock --systohc

# localization
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf
echo "LC_COLLATE=C" >> /etc/locale.conf
echo "KEYMAP=us" >/etc/vconsole.conf

# installing bootloader
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Open-Artix
sed -i -e 's/^GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/g' \
  -e 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

# network configuration
echo "127.0.0.1        localhost" >/etc/hosts
echo "::1              localhost" >> /etc/hosts
echo "127.0.1.1        $HOSTNAME.localdomain  $HOSTNAME" >> /etc/hosts
echo "hostname='$HOSTNAME'" >/etc/conf.d/hostname

# try and restart service in parallel
sed -i 's/^#rc_parallel=\"NO\"/rc_parallel=\"YES\"/g' /etc/rc.conf

# enabling colors and parallel downloads
sed -i "s/^#Color$/Color/" /etc/pacman.conf
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf
grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf

# archlinux-support
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
pacman --noconfirm -S --needed --assume-installed=sudo base-devel opendoas \
  ntp ntp-openrc networkmanager networkmanager-openrc \
  cronie cronie-openrc metalog metalog-openrc openssh-openrc

# adding stuff to the runlevel
SERVICES="elogind ntpd NetworkManager cronie metalog sshd"
for i in $SERVICES; do
  rc-update add $i default
done

# exit from chroot
exit
