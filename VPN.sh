#!/usr/bin/env bash
# Generates a .ovpn file given a client name
#
# $ ./VPN.sh mikeslap
#
# Prerequisites: scp, ssh, openssl

set -euo pipefail
umask 077

client=${1:?Usage: ./VPN.sh CLIENT}
[[ $client =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,26}$ ]] || { echo 'Use 1–27 letters, numbers, underscores or hyphens for CLIENT.' >&2; exit 1; }
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
mkdir -p vpn
work_dir=$(mktemp -d vpn/work-XXXXXXXX)
remote="vpn-${work_dir##*/}"
trap 'ssh -o BatchMode=yes admin@192.168.1.1 "/file remove [find where name~\"^$remote\"]" >/dev/null 2>&1 || true; rm -rf -- "$work_dir"' EXIT

password=$(openssl rand -hex 24)
key_password=$(openssl rand -hex 24)
cat > "$work_dir/setup.rsc" <<EOF
/ppp secret add name="$client" password="$password" service=ovpn profile=ovpn-home
/certificate export-certificate ovpn-ca type=pem file-name="$remote-ca"
/certificate export-certificate ovpn-client type=pem file-name="$remote-client" export-passphrase="$key_password"
:put "VPN_READY"
EOF

scp -O -o BatchMode=yes "$work_dir/setup.rsc" "admin@192.168.1.1:$remote.rsc"
ssh -o BatchMode=yes admin@192.168.1.1 "/import file-name=$remote.rsc" | tr -d '\r' | grep -x VPN_READY
scp -O -o BatchMode=yes "admin@192.168.1.1:$remote-ca.crt" "admin@192.168.1.1:$remote-client.crt" "admin@192.168.1.1:$remote-client.key" "$work_dir/"
key_password="$key_password" openssl pkey -in "$work_dir/$remote-client.key" -passin env:key_password -out "$work_dir/client.key"

cat > "$work_dir/$client.ovpn" <<EOF
client
dev tun
proto tcp4-client
remote foxes.busuttil.ca 1194
nobind
persist-key
persist-tun
remote-cert-tls server
verify-x509-name foxes.busuttil.ca name
tls-version-min 1.2
cipher AES-256-CBC
auth SHA256
route 192.168.1.0 255.255.255.0
dhcp-option DNS 192.168.1.1
dhcp-option DOMAIN lan
verb 3
<auth-user-pass>
$client
$password
</auth-user-pass>
<ca>
$(cat "$work_dir/$remote-ca.crt")
</ca>
<cert>
$(cat "$work_dir/$remote-client.crt")
</cert>
<key>
$(cat "$work_dir/client.key")
</key>
EOF
mv -- "$work_dir/$client.ovpn" "vpn/$client.ovpn"
printf 'Created vpn/%s.ovpn\n' "$client"
