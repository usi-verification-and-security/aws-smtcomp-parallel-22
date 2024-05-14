#!/bin/sh
## Always does a full rebuild
set -e

cd common
docker build --no-cache -t smtcomp-smts:common .
cd ..

cd leader
docker build --no-cache -t smtcomp-smts:leader .
cd ..

cd worker
docker build --no-cache -t smtcomp-smts:worker .
cd ..
