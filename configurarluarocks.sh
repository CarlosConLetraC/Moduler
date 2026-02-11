#!/usr/bin/env bash
set -e

BASE_PATH=$PWD
LUAROCKS_VERSION="3.13.0"

dependencies=( "luajit" "libluajit-5.1-dev" "wget" "make" "gcc" "libssl-dev" "build-essential" "pkg-config" "libssl-dev" "zlib1g-dev" "ca-certificates" "libssh2-1" "libssh2-1-dev" )

sudo apt-get update
for dep in "${dependencies[@]}"; do
    if ! dpkg -l | grep -q $dep; then
        echo "$dep no esta instalado. Instalando..."
        sudo apt-get install -y $dep
    fi
done

cd /tmp
wget https://luarocks.org/releases/luarocks-$LUAROCKS_VERSION.tar.gz
tar zxpf luarocks-$LUAROCKS_VERSION.tar.gz
cd luarocks-$LUAROCKS_VERSION
./configure && make && sudo make install

sudo luarocks install luasocket
sudo luarocks install luasec


if [ -f "/usr/local/lib/libluajit-5.1.so" ] || [ -f "/usr/local/lib/libluajit-5.1.so.2" ]; then
    LUAJIT_LIB_DIR="/usr/local/lib"
    LUAJIT_INCLUDE_DIR="/usr/local/include/luajit-2.1"
elif [ -f "/usr/lib/libluajit-5.1.so" ] || [ -f "/usr/lib/libluajit-5.1.so.2" ]; then
    LUAJIT_LIB_DIR="/usr/lib"
    LUAJIT_INCLUDE_DIR="/usr/include/luajit-2.1"
else
    echo "No se encontró LuaJIT en /usr/local/lib ni en /usr/lib"
    exit 1
fi

echo "LuaJIT detectado en: $LUAJIT_LIB_DIR"

cd /tmp
if [ -d lua-ssh/ ]; then
    rm -rf lua-ssh/
fi

git clone https://github.com/esno/lua-ssh.git
cd lua-ssh/src

gcc -O2 -fPIC -I$LUAJIT_INCLUDE_DIR -c ssh.c -o ssh.o
gcc -shared -o ssh.so ssh.o -L$LUAJIT_LIB_DIR -lluajit-5.1 -lssh2

cp -p ssh.so $BASE_PATH/import/Linux/

echo "OK"
