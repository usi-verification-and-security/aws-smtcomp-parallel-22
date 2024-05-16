#!/bin/bash

SMTS_DOCKER_DIR=docker

AWS_ACCOUNT_NUMBER=683804625309
AWS_PROJECT=comp24

ACTION_REGEX='docker-all|docker-build|docker-run|infra-all|infra-build|infra-upload|infra-delete|infra-run|infra-shutdown|clean|nop'

DOMAIN_REGEX='sat|smt'

function usage {
  printf "USAGE: %s <tool> <domain> <action> [options]\n" "$0"
  printf "DOMAINS: %s\n" "$DOMAIN_REGEX"
  printf "ACTIONS: %s\n" "$ACTION_REGEX"
  printf "OPTIONS:\n"
  printf "\t-P\t\tManage parallel track. Otherwise, manage cloud track.\n"
  printf "\t-c\t\tClean up at the end.\n"
  printf "\t-n\t\tDo not confirm (usually).\n"
  printf "\t-k\t\tKeep alive.\n"

  [[ -n $1 ]] && exit $1
}

################################################################

AWS_INFRA_REPO_DIR=aws-infrastructure

[[ -d $AWS_INFRA_REPO_DIR ]] || {
  printf "Directory %s does not exist! (This should not have hapenned!)\n" "$AWS_INFRA_REPO_DIR" >&2
  exit 1
}

AWS_INFRA_REPO_DOCKER_DIR="$AWS_INFRA_REPO_DIR/docker"
AWS_INFRA_REPO_INFRA_DIR="$AWS_INFRA_REPO_DIR/infrastructure"

[[ -d $AWS_INFRA_REPO_DOCKER_DIR ]] || {
  printf "Submodule %s is not cloned yet, updating ...\n" "$AWS_INFRA_REPO_DIR"
  git submodule update --init --recursive || exit $?
}

[[ -d $AWS_INFRA_REPO_DOCKER_DIR && -d $AWS_INFRA_REPO_INFRA_DIR ]] || {
  printf "Directories %s and %s do not exist! (This should not have hapenned!)\n" "$AWS_INFRA_REPO_DOCKER_DIR" "$AWS_INFRA_REPO_INFRA_DIR" >&2
  exit 1
}

[[ -L $AWS_INFRA_REPO_DOCKER_DIR/smts-images ]] || {
  ln -vrsT "$SMTS_DOCKER_DIR" "$AWS_INFRA_REPO_DOCKER_DIR/smts-images" || exit $?
}

################################################################

[[ -z $1 ]] && {
  printf "Specify a tool, e.g. 'mallob' or 'smts'.\n" >&2
  usage 1
}

TOOL=$1
shift

TOOL_IMAGES_DIRBASE=${TOOL}-images
TOOL_IMAGES_DIR="$AWS_INFRA_REPO_DOCKER_DIR/$TOOL_IMAGES_DIRBASE"
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
DO_UPLOAD_INFRA=0
DO_DELETE_INFRA=0
DO_RUN_INFRA=0
DO_SHUTDOWN_INFRA=0
DO_CLOUD_TRACK=1
DO_CLEANUP=0
DO_CONFIRM=1
DO_KEEP_ALIVE=0

case $ACTION in
  docker-all)
    DO_BUILD_DOCKER=1
    DO_RUN_DOCKER=1
    ;;
  docker-build)
    DO_BUILD_DOCKER=1
    ;;
  docker-run)
    DO_RUN_DOCKER=1
    ;;
  infra-all)
    DO_BUILD_DOCKER=1
    DO_BUILD_INFRA=1
    DO_UPLOAD_INFRA=1
    DO_RUN_INFRA=1
    ;;
  infra-build)
    DO_BUILD_DOCKER=1
    DO_BUILD_INFRA=1
    ;;
  infra-upload)
    DO_UPLOAD_INFRA=1
    ;;
  infra-delete)
    DO_DELETE_INFRA=1
    ;;
  infra-run)
    DO_RUN_INFRA=1
    ;;
  infra-shutdown)
    DO_SHUTDOWN_INFRA=1
    ;;
  clean)
    DO_CLEANUP=1
    ;;
  nop)
    DO_CONFIRM=0
    ;;
  *)
    printf "This should be unreachable! Error at line %d\n" $LINENO >&2
    exit -1
    ;;
esac

while getopts "Pcnk" opt; do
  case $opt in
    P) DO_CLOUD_TRACK=0;;
    c) DO_CLEANUP=1;;
    n) DO_CONFIRM=0;;
    k) DO_KEEP_ALIVE=1;;
    \?) printf -- "Unrecognized option: -%s\n" "$OPTARG" >&2; usage 1;;
    :) printf -- "Option -%s requires an argument.\n" "$OPTARG" >&2; usage 1;;
  esac
done

################################################################

function maybe_confirm {
  (( $DO_CONFIRM )) || {
    echo
    return 0
  }
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
TEST_FILE_RELATIVE=experiment/$TEST_FILEBASE
TEST_FILE_ABSOLUTE="$AWS_INFRA_REPO_DOCKER_DIR/runner/$TEST_FILE_RELATIVE"

AWS_S3_URL=s3://${AWS_ACCOUNT_NUMBER}-us-east-1-${AWS_PROJECT}
AWS_IMAGE_REPO=${AWS_ACCOUNT_NUMBER}.dkr.ecr.us-east-1.amazonaws.com/${AWS_PROJECT}

set -e

TMP=$(mktemp)
docker images >$TMP
echo "Docker images at the beginning:"
cat $TMP
(( $DO_CLEANUP )) || rm -f $TMP
maybe_confirm

################################################################

function satcomp_images {
  pushd "$AWS_INFRA_REPO_DOCKER_DIR/satcomp-images"
  sh build_satcomp_images.sh
  popd

  docker images
  maybe_confirm
}

function tool_images {
  pushd "$TOOL_IMAGES_DIR"
  sh build_${TOOL}_images.sh
  popd

  docker images
  maybe_confirm
}

(( $DO_BUILD_DOCKER )) && {
  satcomp_images
  tool_images
}

function run_parallel_docker {
  pushd "$AWS_INFRA_REPO_DOCKER_DIR/runner"
  sudo chgrp -R 1000 . && chmod 775 .
  bash run_parallel.sh $TOOL_IMAGE_REPO $TEST_FILE_RELATIVE
  maybe_confirm
  rm input.json solver_out.json std{out,err}.log combined_hostfile
  popd
}

function run_cloud_docker {
  pushd "$AWS_INFRA_REPO_DOCKER_DIR/runner"
  xterm -e /bin/bash -c "bash run_dist_worker.sh $TOOL_IMAGE_REPO" &
  xterm -e /bin/bash -c "bash run_dist_leader.sh $TOOL_IMAGE_REPO $TEST_FILE_RELATIVE" &
  sleep 1
  docker ps
  wait
  wait
  maybe_confirm
  rm input.json solver_out.json std{out,err}.log combined_hostfile
  popd
}

(( $DO_RUN_DOCKER )) && {
  (( $DO_KEEP_ALIVE )) && printf "Warning: 'keep-alive' option is currently not supported for action '%s'.\n" $ACTION >&2
  docker network inspect $TOOL_NETWORK &>/dev/null || docker network create $TOOL_NETWORK
  if (( $DO_CLOUD_TRACK )); then
    run_cloud_docker
  else
    run_parallel_docker
  fi
}

################################################################

function build_infra {
  local solver_type=cloud
  (( $DO_CLOUD_TRACK )) || solver_type=parallel

  aws sts get-caller-identity

  pushd "$AWS_INFRA_REPO_INFRA_DIR"
  python3 manage-solver-infrastructure.py --solver-type $solver_type --mode create --project ${AWS_PROJECT}
  popd

  docker images
  maybe_confirm
}

(( $DO_BUILD_INFRA )) && {
  build_infra
}

function upload_infra {
  pushd "$AWS_INFRA_REPO_INFRA_DIR"
  python3 docker-upload-to-ecr.py --leader $TOOL_IMAGE_REPO:leader --worker $TOOL_IMAGE_REPO:worker --project ${AWS_PROJECT}
  popd

  aws s3 cp "$TEST_FILE_ABSOLUTE" $AWS_S3_URL
  aws s3 ls $AWS_S3_URL
  maybe_confirm
}

(( $DO_UPLOAD_INFRA )) && {
  upload_infra
}

function delete_infra {
  pushd "$AWS_INFRA_REPO_INFRA_DIR"
  ./delete-solver-infrastructure
  popd
}

(( $DO_DELETE_INFRA )) && {
  delete_infra
}

function run_infra {
  local keep_alive_opt=()

  (( $DO_KEEP_ALIVE )) && keep_alive_opt=(--keep-alive 1)

  pushd "$AWS_INFRA_REPO_INFRA_DIR"
  ./quickstart-run ${keep_alive_opt[@]} --s3-locations $AWS_S3_URL/$TEST_FILEBASE
  popd
}

(( $DO_RUN_INFRA )) && {
  run_infra
}

function shutdown_infra {
  pushd "$AWS_INFRA_REPO_INFRA_DIR"
  python3 ecs-config shutdown
  popd
}

(( $DO_SHUTDOWN_INFRA )) && {
  shutdown_infra
}

################################################################

function cleanup {
  echo "Cleanup ..."
  docker image inspect satcomp-infrastructure:leader &>/dev/null && docker rmi satcomp-infrastructure:{common,leader,worker}
  docker image inspect $TOOL_IMAGE_REPO:leader &>/dev/null && docker rmi $TOOL_IMAGE_REPO:{common,leader,worker}
  docker image inspect $AWS_IMAGE_REPO:leader &>/dev/null && docker rmi $AWS_IMAGE_REPO:{leader,worker}
  docker network inspect $TOOL_NETWORK &>/dev/null && docker network rm $TOOL_NETWORK
  echo "Pruning docker images removes all dangling <none>/<none> images - not dangerous unless you had some of your own that you still want to use ..."
  echo "Current images:"
  docker images
  docker image prune
  echo -e "\nDocker images at the end:"
  docker images
  echo

  [[ $ACTION != clean ]] && {
    if diff $TMP <(docker images); then
      echo "(No difference compared to the state before running the script.)"
      rm -f $TMP
    else
      printf "Docker images differ with the state before running the script!\nThe previous state is in file: %s\n" $TMP >&2
    fi
  }

  (( $DO_DELETE_INFRA )) || {
    echo
    delete_infra
  }
}

(( $DO_CLEANUP )) && {
  cleanup
}

echo -e "\nSuccess."
exit 0
