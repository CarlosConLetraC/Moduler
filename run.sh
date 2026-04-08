#!/usr/bin/env bash
set -e

if ! command -v java &> /dev/null; then
    ./build.sh
fi

CLASSES_FOUND=$(find . -name "*.class" | wc -l)
if [ "$CLASSES_FOUND" -eq 0 ]; then
    echo "run.sh: No se encontraron .class. Compilando Java. . ."
    find . -name "*.java" > sources.txt
    javac @sources.txt

    if [ $? -ne 0 ]; then
        echo "Error: compilacion fallida."
        exit 1
    fi

    echo "Compilacion completada."
else
    echo "Archivos .class encontrados ($CLASSES_FOUND). Saltando compilacion."
fi

if ! pgrep -x "mongod" > /dev/null; then
    echo "Iniciando MongoDB. . ."
    mkdir -p ~/mongodb-data
    mongod --dbpath ~/mongodb-data > mongo.log 2>&1 &
    sleep 3
fi

java backend
source $PWD/entorno/bin/activate
python airbnb.py > airbnb.py.log 2>&1