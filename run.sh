#!/usr/bin/env bash
set -e

if ! command -v java &> /dev/null; then
    ./build.sh
fi

if ! pgrep -x "mongod" > /dev/null; then
    echo "Iniciando MongoDB..."
    mkdir -p ~/mongodb-data
    mongod --dbpath ~/mongodb-data > mongo.log 2>&1 &
    sleep 3
fi

java backend
./runclient merge.lua
source $PWD/entorno/bin/activate
# python3 innecesario.py
# python3 graficar.py > py.log 2>&1