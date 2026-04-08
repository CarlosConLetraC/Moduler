#!/usr/bin/env bash
set -e

if ! command -v java &> /dev/null; || ! command -v luajit &>/dev/null; then
    ./configurarentorno.sh
fi

javac backend.java