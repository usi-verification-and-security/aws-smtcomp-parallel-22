#!/bin/sh
set -e

cd common
docker build -t smtcomp-smts:common .
cd ..

cd leader
docker build -t smtcomp-smts:leader .
cd ..

cd worker
docker build -t smtcomp-smts:worker .
cd ..
