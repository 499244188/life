#!/bin/bash
set -u
cd "$(dirname "$0")/.."
export TZ="Asia/Shanghai"

python3 -m unittest discover -s tests -q || exit 1
python3 -m zero_lab init --root evolution || exit 1
python3 -m zero_lab cycle --root evolution || exit 1
python3 -m zero_lab verify --root evolution || exit 1
