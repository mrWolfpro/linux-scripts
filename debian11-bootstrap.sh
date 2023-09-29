#!/bin/bash

# Add comments and info here

# Functions definitions

function print_help {
  echo ""
  echo "Usage: $(basename $0) [ --ipv6 ] [ --add-ssh-keys ]"
  echo ""
  echo "    --ipv6            Leave IPv6 protocol enabled"
  echo "    --add-ssh-keys    Add SSH keys to authorized_keys"
  echo "    -h | --help       Print this help message and exit"
  echo ""
  exit 63
}

function args_parse() {
  while [ -n "$1" ]; do
    case "$1" in
      --ipv6) ENABLE_IPV6=1 ;;
      --add-ssh-keys) ADD_SSH_KEYS=1 ;;
      -h|--help) PRINT_HELP=1 ;;
      *) echo; echo "Bad option: $1"; print_help ;;
    esac
    shift
  done
}

function detect_platform {
  MINWAIT=2; MAXWAIT=5
  sleep $((MINWAIT+RANDOM % (MAXWAIT-MINWAIT)))

  dmidecode -t 1 | grep -qi qemu
  if [ $? -eq 0 ]; then
    echo "QEMU platform detected"
    platform_agent="qemu-guest-agent"
  fi

  dmidecode -t 1 | grep -qi vmware
  if [ $? -eq 0 ]; then
    echo "VMware platform detected"
    platform_agent="open-vm-tools"
  fi

  sleep 1
}

function set_bashrc_vars() {
cat << 'EOF' >> $1

alias ll='ls -l'
alias p='ping'
alias t='traceroute'
alias tailf='tail -f'

if [ $(/usr/bin/whoami) = 'root' ]; then
  if [ "$TERM" != 'dumb'  ] && [ -n "$BASH" ]; then
    export PS1='\[\033[01;31m\]\h \[\033[01;34m\]\W \$ \[\033[00m\]'
  fi
else
  if [ "$TERM" != 'dumb'  ] && [ -n "$BASH" ]; then
    export PS1='\[\033[01;32m\]\u@\h \[\033[01;34m\]\W \$ \[\033[00m\]'
  fi
fi
EOF
}

function disable_ipv6 {
cat << EOF > /etc/sysctl.d/90-disable-ipv6.conf
##############################################################
# Disable IPv6
#
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
sysctl -p /etc/sysctl.d/90-disable-ipv6.conf > /dev/null 2>&1
}

function set_ssh_keys() {
user=$1
if [ $user = 'root' ]; then
  echo "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBPn+z0a0dIYNoWb0k2cUTy+1gLs3wVB4NCq0d7po/whmgpEBe7bSlo64hUSzj6Xd53dINcPSKJfFihJmxOIN2oo=" >> /root/.ssh/authorized_keys
  echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICsBJfZ0dOcVLiol9i2QSySDMKlhC5MOhjzXB17ydInw" >> /root/.ssh/authorized_keys
else
  if [ -d /home/$user ]; then
    group=$user
    mkdir /home/$user/.ssh
    chmod 0700 /home/$user/.ssh
    chown $user:$group /home/$user/.ssh
    echo "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBPn+z0a0dIYNoWb0k2cUTy+1gLs3wVB4NCq0d7po/whmgpEBe7bSlo64hUSzj6Xd53dINcPSKJfFihJmxOIN2oo=" >> /home/$user/.ssh/authorized_keys
    echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICsBJfZ0dOcVLiol9i2QSySDMKlhC5MOhjzXB17ydInw" >> /root/.ssh/authorized_keys
  fi
fi
}

# Main procedure

args_parse $@
[[ ! -z $PRINT_HELP ]] && print_help

echo -n "Detecting hardware platform: "
detect_platform

echo -n "Setting up bashrc parameters: "
set_bashrc_vars "/root/.bashrc"
set_bashrc_vars "/etc/skel/.bashrc"
for user in daem0n ianokhin; do
  if [ -f /home/$user/.bashrc ]; then
    set_bashrc_vars "/home/$user/.bashrc"
  fi
done
echo "done"

if [ -z $ENABLE_IPV6 ]; then
  echo -n "Setting up networking: "
  disable_ipv6 && echo "IPv6 disabled" || echo "failed to disable IPv6"
fi

echo -n "Setting up SSH server: "
cat << EOF > /etc/ssh/sshd_config.d/10-sshd-custom.conf
Port 22
AddressFamily inet
EOF
systemctl restart ssh > /dev/null 2>&1 && echo "done" || echo "failed!"

if [ ! -z $ADD_SSH_KEYS ]; then
  echo -n "Setting up SSH keys: "
  for user in root daem0n ianokhin; do
    set_ssh_keys $user
  done
  echo "done"
fi

echo -n "Setting up nanorc: "
sed -i 's/# set tabsize 8/set tabsize 4/' /etc/nanorc
#sed -i 's/# set tabstospaces/set tabstospaces/' /etc/nanorc
echo "done"

echo -n "Setting up sources.list: "
cat << EOF > /etc/apt/sources.list && echo "done" || echo "failed!"
deb http://mirror.yandex.ru/debian/ bullseye main
deb-src http://mirror.yandex.ru/debian/ bullseye main

deb http://security.debian.org/debian-security bullseye-security main
deb-src http://security.debian.org/debian-security bullseye-security main

deb http://mirror.yandex.ru/debian/ bullseye-updates main
deb-src http://mirror.yandex.ru/debian/ bullseye-updates main
EOF

echo -n "Updating system software: "
apt update > /dev/null 2>&1 || "echo failed!; exit 10"
apt upgrade -y > /dev/null 2>&1 && echo done || "echo failed!; exit 11"

echo -n "Installing additional software: "
apt install -y command-not-found curl dnsutils htop net-tools sockstat sysstat tcpdump traceroute $platform_agent > /dev/null 2>&1 && echo done || "echo failed!; exit 12"
echo -n "Performing cleanup: "
apt-file update > /dev/null 2>&1 || "echo failed!; exit 13"
update-command-not-found > /dev/null 2>&1 && echo done || "echo failed!; exit 14"

echo "Server bootstrap finished successfully!"
