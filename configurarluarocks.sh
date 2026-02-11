#!/usr/bin/env bash
set -e

BASE_PATH=$PWD
LUAROCKS_VERSION="3.13.0"

dependencies=(
    "luajit"
    "libluajit-5.1-dev"
    "wget"
    "make"
    "gcc"
    "build-essential"
    "pkg-config"
    "libssl-dev"
    "zlib1g-dev"
    "ca-certificates"
    "libssh2-1"
    "libssh2-1-dev"
    "git"
)

sudo apt-get update
for dep in "${dependencies[@]}"; do
    if ! dpkg -s "$dep" &>/dev/null; then
        echo "$dep no está instalado. Instalando..."
        sudo apt-get install -y "$dep"
    fi
done

cd /tmp
wget -q https://luarocks.org/releases/luarocks-$LUAROCKS_VERSION.tar.gz
tar zxpf luarocks-$LUAROCKS_VERSION.tar.gz
cd luarocks-$LUAROCKS_VERSION
./configure && make && sudo make install

sudo luarocks install luasocket
sudo luarocks install luasec


cd /tmp
rm -rf lua-ssh
git clone https://github.com/esno/lua-ssh.git
cd lua-ssh/src

gcc -O2 -fPIC -I/usr/include/luajit-2.1 -c ssh.c -o ssh.o
gcc -shared -o ssh.so ssh.o -lluajit-5.1 -lssh2

mkdir -p "$BASE_PATH/import/Linux/"
cp -p ssh.so "$BASE_PATH/import/Linux/"

echo "OK"
