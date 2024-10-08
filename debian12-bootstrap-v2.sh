#!/bin/bash

# Add comments and info here

# Functions definitions

function print_help {
	echo ""
	echo "Usage: $(basename $0) [ --add-ssh-keys ] [ --enable-root-login ] [ --enable-ipv6 ] [ --enable-pxm ]"
	echo ""
	echo "    --add-ssh-keys        Add SSH keys to authorized_keys"
	echo "    --enable-root-login   Permit root login with password"
	echo "    --enable-ipv6         Enable IPv6 protocol support"
	echo "    --enable-pxm          Add Proxmox-specific configuration"
	echo "    -h | --help           Print this help message and exit"
	echo ""
	exit 63
}

function args_parse() {
	while [ -n "$1" ]; do
		case "$1" in
			--add-ssh-keys) ADD_SSH_KEYS=1 ;;
			--enable-root-login) PERMIT_ROOT=1 ;;
			--enable-ipv6) ENABLE_IPV6=1 ;;
			--enable-pxm) ENABLE_PXM=1 ;;
			-h|--help) PRINT_HELP=1 ;;
			*) echo; echo "Bad option: $1"; print_help ;;
		esac
		shift
	done
}

function detect_platform {
	MINWAIT=2; MAXWAIT=5
	sleep $((MINWAIT+RANDOM % (MAXWAIT-MINWAIT)))

	HYPERVISOR=$(lscpu | grep "Hypervisor vendor" | cut -d: -f2 | sed -e 's/\ //g')

	if [ "$HYPERVISOR" = "KVM" ]; then
		echo "KVM platform detected"
		PLATFORM_AGENT="qemu-guest-agent"
	elif [ "$HYPERVISOR" = "VMware" ]; then
		echo "VMware platform detected"
		PLATFORM_AGENT="open-vm-tools"
	else
		echo "not detected, assuming bare-metal or LXC"
	fi

	sleep $((MINWAIT+RANDOM % (MAXWAIT-MINWAIT)))
}

function set_bashrc_vars() {
cat << 'EOF' >> $1

alias ll='ls -l'
alias lla='ls -la'
alias tailf='tail -f'
alias t='traceroute'
alias p='ping'

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
		echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHz65hcol8K2xBXDSDOyNQnfvio6sHuABm3tL6S5NZud Ilia Anokhin" >> /root/.ssh/authorized_keys
	else
		if [ -d /home/$user ]; then
			group=$user
			mkdir /home/$user/.ssh
			chmod 0700 /home/$user/.ssh
			chown $user:$group /home/$user/.ssh
			echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHz65hcol8K2xBXDSDOyNQnfvio6sHuABm3tL6S5NZud Ilia Anokhin" >> /home/$user/.ssh/authorized_keys
		fi
	fi
}

# Main procedure

args_parse $@
[[ ! -z $PRINT_HELP ]] && print_help

echo -n "Detecting hypervisor: "
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
if [ ! -z $PERMIT_ROOT ]; then
	echo "PermitRootLogin yes" >> /etc/ssh/sshd_config.d/10-sshd-custom.conf
fi
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
deb http://mirror.yandex.ru/debian/ bookworm main
deb-src http://mirror.yandex.ru/debian/ bookworm main

deb http://security.debian.org/debian-security bookworm-security main
deb-src http://security.debian.org/debian-security bookworm-security main

deb http://mirror.yandex.ru/debian/ bookworm-updates main
deb-src http://mirror.yandex.ru/debian/ bookworm-updates main
EOF

echo -n "Updating system software: "
apt update > /dev/null 2>&1 || "echo failed!; exit 10"
apt upgrade -y > /dev/null 2>&1 && echo done || "echo failed!; exit 11"

echo -n "Installing additional software: "
apt install -y command-not-found dnsutils haveged htop net-tools sockstat sysstat tcpdump traceroute $PLATFORM_AGENT > /dev/null 2>&1 && echo done || "echo failed to install packages!; exit 12"
echo -n "Performing cleanup: "
apt autoremove -y > /dev/null 2>&1 || "echo apt autoremove failed!; exit 13"
apt-file update > /dev/null 2>&1 || "echo apt-file update failed!; exit 14"
update-command-not-found > /dev/null 2>&1 && echo done || "echo update command-not-found failed!; exit 15"

echo "Server bootstrap finished successfully!"
