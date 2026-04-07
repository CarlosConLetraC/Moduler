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
source $PWD/entorno/bin/activate
python airbnb.py > airbnb.py.log 2>&1