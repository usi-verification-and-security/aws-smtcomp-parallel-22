#!/bin/bash

## Only works in Linux

HOSTFILE="$1"
PROBLEM_PATH="$2"
N_NODES=$3

N_CPU=$(nproc)

## May be also parametrized whether to run in portfolio mode (-> omit '-p')

(( $N_NODES == 1 )) && {
  N_PROC_RATIO=0.25
  N_SOLVERS=$(python3 <<<"print(int($N_CPU * $N_PROC_RATIO))")

  exec python3 SMTS/server/smts.py -p -l -o$N_SOLVERS -fp "$PROBLEM_PATH"
}

SERVER_IP=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
SERVER_PORT=3000

#run smts server
python3 SMTS/server/smts.py -p &
sleep 1

#run lemma server
SMTS/build/lemma_server -s$SERVER_IP:$SERVER_PORT &

#run solver clients
# TK : I do not understand how exactly -n <N> and --map-by node:PE=4 works
# TK: should N_CPU be utilized here or not?
N_PROCESSES=$(($N_NODES * 4))
mpirun --mca btl_tcp_if_include eth0 --allow-run-as-root -n $N_PROCESSES \
  --hostfile "$HOSTFILE" --use-hwthread-cpus --map-by node:PE=4 --bind-to none --report-bindings \
  SMTS/build/solver_opensmt -s$SERVER_IP:$SERVER_PORT &

#send instance
python3 SMTS/server/client.py $SERVER_PORT "$PROBLEM_PATH"

wait
