#!/bin/bash

AWS_ACCOUNT_NUMBER=683804625309
AWS_PROJECT=comp24

ACTION_REGEX='docker|docker-build|docker-run|infra|infra-build|infra-delete|infra-run|nop'

DOMAIN_REGEX='sat|smt'

function usage {
  printf "USAGE: %s <tool> <domain> <action> [options]\n" "$0"
  printf "DOMAINS %s:\n" "$DOMAIN_REGEX"
  printf "ACTIONS %s:\n" "$ACTION_REGEX"
  printf "OPTIONS:\n"
  printf "\t-C\t\tClean up at the end.\n"
  printf "\t-n\t\tDo not confirm (usually).\n"

  [[ -n $1 ]] && exit $1
}

################################################################

[[ -z $1 ]] && {
  printf "Specify a tool, e.g. '%s'.\n" mallob >&2
  usage 1
}

TOOL=$1
shift

TOOL_IMAGES_DIRBASE=${TOOL}-images
TOOL_IMAGES_DIR=docker/$TOOL_IMAGES_DIRBASE
[[ -d $TOOL_IMAGES_DIR ]] || {
  printf "Invalid tool '%s': directory '%s' does not exist.\n" $TOOL "$TOOL_IMAGES_DIR" >&2
  usage 1
}
[[ $TOOL_IMAGES_DIRBASE == satcomp-images ]] && {
  printf "Invalid tool '%s': directory '%s' is reserved.\n" $TOOL "$TOOL_IMAGES_DIR" >&2
  usage 1
}

[[ $1 =~ ^($DOMAIN_REGEX)$ ]] || {
  printf "Expected a domain, one of %s, got: %s\n" "$DOMAIN_REGEX" "$1" >&2
  usage 1
}
DOMAIN=$1
shift

[[ $1 =~ ^($ACTION_REGEX)$ ]] || {
  printf "Expected an action, one of %s, got: %s\n" "$ACTION_REGEX" "$1" >&2
  usage 1
}

ACTION=$1
shift

DO_BUILD_DOCKER=0
DO_RUN_DOCKER=0
DO_BUILD_INFRA=0
DO_DELETE_INFRA=0
DO_RUN_INFRA=0
DO_CLEANUP=0
DO_CONFIRM=1

case $ACTION in
  docker)
    DO_BUILD_DOCKER=1
    DO_RUN_DOCKER=1
    ;;
  docker-build)
    DO_BUILD_DOCKER=1
    ;;
  docker-run)
    DO_RUN_DOCKER=1
    ;;
  infra)
    DO_BUILD_DOCKER=1
    DO_BUILD_INFRA=1
    DO_RUN_INFRA=1
    ;;
  infra-build)
    DO_BUILD_DOCKER=1
    DO_BUILD_INFRA=1
    ;;
  infra-delete)
    DO_DELETE_INFRA=1
    ;;
  infra-run)
    DO_RUN_INFRA=1
    ;;
  nop)
    DO_CONFIRM=0
    ;;
  *)
    printf "This should be unreachable! Error at line %d\n" $LINENO >&2
    exit -1
    ;;
esac

while getopts "Cn" opt; do
  case $opt in
    C) DO_CLEANUP=1;;
    n) DO_CONFIRM=0;;
    \?) printf -- "Unrecognized option: -%s\n" "$OPTARG" >&2; usage 1;;
    :) printf -- "Option -%s requires an argument.\n" "$OPTARG" >&2; usage 1;;
  esac
done

################################################################

function maybe_confirm {
  (( $DO_CONFIRM )) || return 0
  echo "Confirm to continue ..."
  read
}

TOOL_IMAGE_REPO=${DOMAIN}comp-${TOOL}
#TOOL_NETWORK=${TOOL}-test
TOOL_NETWORK=mallob-test

TEST_FILEBASE=test.
case $DOMAIN in
  sat) TEST_FILEBASE+=cnf;;
  smt) TEST_FILEBASE+=smt2;;
  *)
    printf "This should be unreachable! Error at line %d\n" $LINENO >&2
    exit -1
    ;;
esac
TEST_FILE=experiment/$TEST_FILEBASE

AWS_S3_URL=s3://${AWS_ACCOUNT_NUMBER}-us-east-1-${AWS_PROJECT}

set -e

TMP=$(mktemp)
docker images >$TMP
echo "Docker images at the beginning:"
cat $TMP
(( $DO_CLEANUP )) || rm -f $TMP
maybe_confirm

################################################################

function satcomp_images {
  cd docker/satcomp-images
  sh build_satcomp_images.sh
  cd ../..
  docker images
  maybe_confirm
}

function tool_images {
  cd "$TOOL_IMAGES_DIR"
  sh build_${TOOL}_images.sh
  cd ../..
  docker images
  maybe_confirm
}

(( $DO_BUILD_DOCKER )) && {
  satcomp_images
  tool_images
}

function run_parallel_docker {
  cd docker/runner
  sudo chgrp -R 1000 . && chmod 775 .
  bash run_parallel.sh $TOOL_IMAGE_REPO $TEST_FILE
  maybe_confirm
  rm input.json solver_out.json std{out,err}.log combined_hostfile
  cd ../..
}

function run_dist_docker {
  cd docker/runner
  xterm -e /bin/bash -c "bash run_dist_worker.sh $TOOL_IMAGE_REPO" &
  xterm -e /bin/bash -c "bash run_dist_leader.sh $TOOL_IMAGE_REPO $TEST_FILE" &
  sleep 1
  docker ps
  wait
  wait
  maybe_confirm
  rm input.json solver_out.json std{out,err}.log combined_hostfile
  cd ../..
}

(( $DO_RUN_DOCKER )) && {
  docker network inspect $TOOL_NETWORK &>/dev/null || docker network create $TOOL_NETWORK
  run_parallel_docker
  run_dist_docker
}

################################################################

function build_infra {
  cd infrastructure
  python3 manage-solver-infrastructure.py --solver-type cloud --mode create --project ${AWS_PROJECT}
  cd ..
}

function upload_infra {
  cd infrastructure
  python3 docker-upload-to-ecr.py --leader $TOOL_IMAGE_REPO:leader --worker $TOOL_IMAGE_REPO:worker --project ${AWS_PROJECT}
  cd ..

  aws s3 cp docker/runner/$TEST_FILE $AWS_S3_URL
  aws s3 ls $AWS_S3_URL
  maybe_confirm
}

(( $DO_BUILD_INFRA )) && {
  build_infra
  upload_infra
}

function delete_infra {
  cd infrastructure
  ./delete-solver-infrastructure
  cd ..
}

(( $DO_DELETE_INFRA )) && {
  delete_infra
}

function run_infra {
  cd infrastructure
  ./quickstart-run --s3-locations $AWS_S3_URL/$TEST_FILEBASE
  cd ..
}

(( $DO_RUN_INFRA )) && {
  run_infra
}

################################################################

function cleanup {
  echo "Cleanup ..."
  docker rmi satcomp-infrastructure:{common,leader,worker}
  docker rmi $TOOL_IMAGE_REPO:{common,leader,worker}
  docker network rm $TOOL_NETWORK
  echo "Pruning docker images removes all dangling <none>/<none> images - not dangerous unless you had some of your own that you still want to use ..."
  echo "Current images:"
  docker images
  docker image prune
  echo -e "\nDocker images at the end:"
  docker images

  diff $TMP <(docker images) || {
    printf "Docker images differ with the state before running the script!\nThe previous state is in file: %s\n" $TMP >&2
    exit 10
  }
  echo "(No difference compared to the state before running the script.)"

  rm -f $TMP
}

(( $DO_CLEANUP )) && {
  cleanup
}

echo -e "\nSuccess."
exit 0
