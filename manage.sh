#!/bin/bash
# This script is for automation, it has minimum output and require no user
# confirmation. Know what you are doing before continue!

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
SYS_DT=$(date +%F-%T)

exiterr()  { echo "Error: $1" >&2; exit 1; }
conf_bk() { /bin/cp -f "$1" "$1.old-$SYS_DT" 2>/dev/null; }
clear_bk() { /bin/mv "$1" "$1.old-$SYS_DT" 2>/dev/null; }

common_check() {
if [ "$(id -u)" != 0 ]; then
  exiterr "Script must be run as root. Try 'sudo sh $0'"
fi

if [ ! -f "/etc/ppp/chap-secrets" ] || [ ! -f "/etc/ipsec.d/passwd" ]; then
  exiterr "File /etc/ppp/chap-secrets and/or /etc/ipsec.d/passwd do not exist!"
fi
}

# set_vpn_secret() {
# secret=$1
# # Specify IPsec PSK
# clear_bk "/etc/ipsec.d/default.secrets"
# touch "/etc/ipsec.d/default.secrets"
# cat > /etc/ipsec.d/default.secrets <<EOF
# %any  %any  : PSK "${secret}"
# EOF
# }

reset_vpn_user() {
if [ "$(id -u)" != 0 ]; then
  exiterr "Script must be run as root. Try 'sudo sh $0'"
fi

clear_bk "/etc/ipsec.d/passwd"
touch "/etc/ipsec.d/passwd"
cat > /etc/ipsec.d/passwd <<EOF
# ======= Encrytions =======
# user:encrypted_pwd:encryption_method
EOF
clear_bk "/etc/ppp/chap-secrets"
touch "/etc/ppp/chap-secrets"
cat > /etc/ppp/chap-secrets <<EOF
# ======= Secrets for authentication using CHAP =======
# client  server  secret  IP addresses
EOF
}

list_vpn_user() {
common_check
cat /etc/ppp/chap-secrets
cat /etc/ipsec.d/passwd
}

update_vpn_user() {
common_check

VPN_USER=$1
VPN_PASSWORD=$2
echo $VPN_USER
echo $VPN_PASSWORD

if [ -z "$VPN_USER" ] || [ -z "$VPN_PASSWORD" ]; then
  exiterr "Usage: sudo sh $0 'username' 'password'"
fi

if printf '%s' "$VPN_USER $VPN_PASSWORD" | LC_ALL=C grep -q '[^ -~]\+'; then
  exiterr "VPN credentials must not contain non-ASCII characters."
fi

case "$VPN_USER $VPN_PASSWORD" in
  *[\\\"\']*)
    exiterr "VPN credentials must not contain these special characters: \\ \" '"
    ;;
esac

# Backup config files
conf_bk "/etc/ppp/chap-secrets"
conf_bk "/etc/ipsec.d/passwd"

# Add or update VPN user
sed -i "/^\"$VPN_USER\" /d" /etc/ppp/chap-secrets
cat >> /etc/ppp/chap-secrets <<EOF
"$VPN_USER" l2tpd "$VPN_PASSWORD" *
EOF

# shellcheck disable=SC2016
sed -i '/^'"$VPN_USER"':\$1\$/d' /etc/ipsec.d/passwd
VPN_PASSWORD_ENC=$(openssl passwd -1 "$VPN_PASSWORD")
cat >> /etc/ipsec.d/passwd <<EOF
$VPN_USER:$VPN_PASSWORD_ENC:xauth-psk
EOF

# Update file attributes
chmod 600 /etc/ppp/chap-secrets* /etc/ipsec.d/passwd*
}

if [[ $1 == "ls" ]]; then list_vpn_user; fi
if [[ $1 == "update" ]]; then update_vpn_user $2 $3; fi
if [[ $1 == "del" ]]; then del_vpn_user $2; fi
if [[ $1 == "reset" ]]; then reset_vpn_user; fi

# exit 0
