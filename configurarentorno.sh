#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Iniciando instalacion. . ."

export MAKEFLAGS="-j$(nproc || echo 2)"
export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/share/pkgconfig"

BASE_PATH="$PWD"
LUAROCKS_VERSION="3.13.0"

source /etc/os-release
OS=$ID
CODENAME="${VERSION_CODENAME:-}"

if [ -z "$CODENAME" ]; then
	echo "[ERROR] VERSION_CODENAME vacio."
	exit 1
fi

echo "[INFO] OS: $OS ($CODENAME)"

java -version > /dev/null 2>&1 && JAVA_INSTALADO=0 || JAVA_INSTALADO=1
mongod --version > /dev/null 2>&1 && MONGOD_INSTALADO=0 || MONGOD_INSTALADO=1
luarocks --version > /dev/null 2>&1 && LUAROCKS_INSTALADO=0 || LUAROCKS_INSTALADO=1

dependencies=(
	luajit wget curl make cmake gfortran gcc g++ build-essential pkg-config
	libssl-dev zlib1g-dev ca-certificates git
	libproj-dev libgeos-dev libgdal-dev
	libblas-dev liblapack-dev
	libwebp-dev protobuf-compiler libprotobuf-dev
	libluajit-5.1-dev libssh2-1-dev
	librsvg2-dev libcurl4-openssl-dev libxml2-dev
	libgit2-dev libjpeg-dev libtiff5-dev libpng-dev
	libfribidi-dev libharfbuzz-dev libcairo2-dev libfontconfig1-dev
	libreadline-dev libncurses-dev unzip zip
	python3-venv python3-pip
)

if [ "$OS" = "ubuntu" ]; then
	dependencies+=(libfreetype6-dev)
elif [ "$OS" = "debian" ]; then
	dependencies+=(libfreetype-dev)
else
	echo "[ERROR] Distribucion no soportada: $OS"
	exit 1
fi

echo "[INFO] Instalando dependencias. . ."
sudo apt-get update -y
sudo apt-get install -y "${dependencies[@]}"

if [ "$LUAROCKS_INSTALADO" -ne 0 ]; then
	echo "[INFO] Instalando LuaRocks $LUAROCKS_VERSION. . ."

	cd /tmp
	wget -q "https://luarocks.org/releases/luarocks-$LUAROCKS_VERSION.tar.gz"
	tar zxf "luarocks-$LUAROCKS_VERSION.tar.gz"
	cd "luarocks-$LUAROCKS_VERSION"

	./configure \
		--with-lua-include=/usr/include/luajit-2.1 \
		--with-lua-bin=/usr/bin \
		--lua-suffix=jit \
		--lua-version=5.1

	make
	sudo make install

	rm -rf "/tmp/luarocks-$LUAROCKS_VERSION"
fi

echo "[INFO] Instalando paquetes Lua. . ."
sudo luarocks install luasocket || true
sudo luarocks install luasec || true

if [ ! -f "$BASE_PATH/import/Linux/ssh.so" ]; then
	echo "[INFO] Compilando lua-ssh. . ."

	cd /tmp
	rm -rf lua-ssh
	git clone https://github.com/esno/lua-ssh.git
	cd lua-ssh/src

	gcc -O2 -fPIC -I/usr/include/luajit-2.1 -c ssh.c -o ssh.o
	gcc -shared -o ssh.so ssh.o -lluajit-5.1 $(pkg-config --libs libssh2 || echo "-lssh2")

	mkdir -p "$BASE_PATH/import/Linux/"
	cp ssh.so "$BASE_PATH/import/Linux/"

	rm -rf /tmp/lua-ssh
fi

if [ "$JAVA_INSTALADO" -ne 0 ]; then
	echo "[INFO] Instalando OpenJDK 21. . ."
	sudo apt-get install -y openjdk-21-jdk
fi

java -version || true

if [ "$MONGOD_INSTALADO" -ne 0 ]; then
	echo "[INFO] Instalando MongoDB. . ."

	MONGO_DIST="$CODENAME"
	MONGO_COMPONENT="main"

	if [ "$OS" = "ubuntu" ]; then
		MONGO_COMPONENT="multiverse"
	elif [ "$OS" = "debian" ]; then
		MONGO_COMPONENT="main"
	fi

	REPO_URL="https://repo.mongodb.org/apt/$OS/dists/$MONGO_DIST/mongodb-org/8.0/$MONGO_COMPONENT/binary-amd64/Packages"

	if ! wget -qO- "$REPO_URL" | grep -q "Package: mongodb-org"; then
		echo "[WARN] Repo vacio o no valido para $OS/$MONGO_DIST"

		if [ "$OS" = "debian" ]; then
			echo "[INFO] Fallback a bookworm"
			MONGO_DIST="bookworm"
		else
			echo "[INFO] Fallback a jammy"
			MONGO_DIST="jammy"
		fi
	fi

	echo "[INFO] Usando repo MongoDB: $OS $MONGO_DIST ($MONGO_COMPONENT)"
	wget -qO- https://www.mongodb.org/static/pgp/server-8.0.asc | sudo tee /usr/share/keyrings/mongodb-server-8.0.gpg >/dev/null
	echo "deb [ arch=amd64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/$OS $MONGO_DIST/mongodb-org/8.0 $MONGO_COMPONENT" | sudo tee /etc/apt/sources.list.d/mongodb-org.list

	sudo apt-get update -y
	sudo apt-get install -y mongodb-org

	sudo systemctl enable mongod
	sudo systemctl start mongod

	mongod --version | head -n1
fi

echo "[INFO] Configurando entorno Python..."
VENV_PATH="$BASE_PATH/entorno"

if [ ! -d "$VENV_PATH" ]; then
	echo "[INFO] Creando entorno virtual..."
	python3 -m venv "$VENV_PATH"
fi

"$VENV_PATH/bin/python" -m pip install --upgrade pip setuptools wheel
"$VENV_PATH/bin/pip" install pymongo matplotlib pandas numpy scikit-learn umap-learn plotly dash seaborn

echo "[INFO] Instalacion completada correctamente."