#!/usr/bin/env bash
set -euo pipefail

export MAKEFLAGS="-j$(nproc)"
export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig"
BASE_PATH="$PWD"
LUAROCKS_VERSION="3.13.0"

source /etc/os-release
OS=$ID
CODENAME="${VERSION_CODENAME:-}"

if [ -z "$CODENAME" ]; then
    echo "ERROR: VERSION_CODENAME is empty"
    exit 1
fi

if [ "$OS" = "ubuntu" ]; then
    dependencies=(
        luajit wget curl make cmake gfortran gcc g++ build-essential pkg-config
        libssl-dev zlib1g-dev ca-certificates git libproj-dev libgeos-dev libgdal-dev
        libblas-dev liblapack-dev libwebpmux3 libwebp-dev protobuf-compiler libprotobuf-dev
        libluajit-5.1-dev libssh2-1 libssh2-1-dev librsvg2-dev libcurl4-openssl-dev libxml2-dev
        libgit2-dev libjpeg-dev libtiff5-dev libpng-dev libfreetype6-dev libfribidi-dev
        libharfbuzz-dev libcairo2-dev libfontconfig1-dev libreadline-dev libncurses-dev unzip zip
        python3-venv python3-pip
    )
elif [ "$OS" = "debian" ]; then
    dependencies=(
        luajit wget curl make cmake gfortran gcc build-essential pkg-config
        libssl-dev zlib1g-dev ca-certificates git libproj-dev libgeos-dev libgdal-dev
        libblas-dev liblapack-dev libwebp-dev protobuf-compiler libprotobuf-dev
        libluajit-5.1-dev libssh2-1-dev librsvg2-dev libcurl4-openssl-dev libxml2-dev
        libgit2-dev libjpeg-dev libtiff5-dev libpng-dev libfreetype-dev libfribidi-dev
        libharfbuzz-dev libcairo2-dev libfontconfig1-dev libreadline-dev libncurses-dev
        libc6 libstdc++6 zlib1g libasound2 unzip zip python3-venv python3-pip
    )
else
    echo "ERROR: Distribucion no disponible: $OS"
    exit 1
fi

sudo apt-get update
sudo apt-get install -y "${dependencies[@]}"

if ! command -v luarocks &>/dev/null || ! luarocks --version | grep -q "$LUAROCKS_VERSION"; then
    echo "Instalando LuaRocks $LUAROCKS_VERSION..."
    cd /tmp
    wget -q https://luarocks.org/releases/luarocks-$LUAROCKS_VERSION.tar.gz
    tar zxpf luarocks-$LUAROCKS_VERSION.tar.gz
    cd luarocks-$LUAROCKS_VERSION
    ./configure \
        --with-lua-include=/usr/include/luajit-2.1 \
        --with-lua-bin=/usr/bin \
        --lua-suffix=jit \
        --lua-version=5.1
    make
    sudo make install
fi

sudo luarocks install luasocket || true
sudo luarocks install luasec || true

cd /tmp
rm -rf lua-ssh
git clone https://github.com/esno/lua-ssh.git
cd lua-ssh/src
gcc -O2 -fPIC -I/usr/include/luajit-2.1 -c ssh.c -o ssh.o
gcc -shared -o ssh.so ssh.o -lluajit-5.1 $(pkg-config --libs libssh2)
mkdir -p "$BASE_PATH/import/Linux/"
cp -p ssh.so "$BASE_PATH/import/Linux/"
sudo rm -rf /tmp/luarocks-$LUAROCKS_VERSION* /tmp/lua-ssh

if ! command -v java &>/dev/null || ! java -version 2>&1 | grep -q "25"; then
    echo "Instalando JDK 25. . ."
    cd /tmp
    JDK_DEB="jdk-25_linux-x64_bin.deb"
    JDK_URL="https://download.oracle.com/java/25/latest/$JDK_DEB"
    wget -q -O "$JDK_DEB" "$JDK_URL"
    sudo dpkg -i "$JDK_DEB" || sudo apt-get install -f -y
    rm -f "$JDK_DEB"
    JAVA_PATH=$(update-alternatives --list java | grep jdk-25 | head -n1 || true)
    [ -n "$JAVA_PATH" ] && sudo update-alternatives --set java "$JAVA_PATH"
fi
java -version || true

if ! command -v mongod &>/dev/null; then
    echo "Instalando MongoDB. . ."
    MONGODB_VERSION="8.2.6"
    MONGO_DEB="mongodb-org-server_${MONGODB_VERSION}_amd64.deb"
    MONGO_DIST="$CODENAME"
    BASE_URL="https://repo.mongodb.org/apt/${OS}/dists"
    if ! wget -q --spider "${BASE_URL}/${MONGO_DIST}/"; then
        echo "MongoDB repo for ${MONGO_DIST} not found, falling back to jammy"
        MONGO_DIST="jammy"
    fi
    MONGODB_URL="${BASE_URL}/${MONGO_DIST}/mongodb-org/8.2/multiverse/binary-amd64/${MONGO_DEB}"
    cd /tmp
    wget -q -O "$MONGO_DEB" "$MONGODB_URL"
    sudo dpkg -i "$MONGO_DEB" || sudo apt-get install -f -y
    rm -f "$MONGO_DEB"
    sudo systemctl enable mongod
    sudo systemctl start mongod
    mongod --version | head -n1
fi

if [ "$OS" = "ubuntu" ] && ! command -v mongosh &>/dev/null; then
    echo "Instalando mongosh. . ."
    wget -qO- https://www.mongodb.org/static/pgp/server-8.0.asc | sudo tee /etc/apt/trusted.gpg.d/server-8.0.asc
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-8.2.list
    sudo apt-get update
    sudo apt-get install -y mongodb-mongosh-shared-openssl3
    mongosh --version || true
fi

python3 -m pip install --upgrade pip setuptools wheel
VENV_PATH="$BASE_PATH/entorno"
if [ ! -d "$VENV_PATH" ] || [ ! -f "$VENV_PATH/bin/activate" ]; then
    echo "Recreando entorno virtual. . ."
    rm -rf "$VENV_PATH"
    python3 -m venv "$VENV_PATH"
    source "$BASE_PATH/entorno/bin/activate"
    python -m pip install pymongo matplotlib pandas numpy scikit-learn umap-learn plotly dash
fi

echo "Instalacion completada."
