# SMT-COMP Parallel & Cloud Track Participant: SMTS

This repository provides scripts to build Docker images and maintain AWS resources
of our solver
[SMTS](https://github.com/usi-verification-and-security/SMTS/tree/cube-and-conquer),
in order to participate in SMT-COMP Parallel & Cloud Track
2024.

We follow the instructions given by the organizers [here](https://github.com/aws-samples/aws-batch-comp-infrastructure-sample).
We also use a [fork](https://github.com/Tomaqa/aws-batch-comp-infrastructure-sample) of the repository as a submodule and reuse some of their sample scripts.

Our parallel & cloud solver SMTS computes on top of our SMT solver [OpenSMT](https://github.com/usi-verification-and-security/opensmt).

## Prerequisites

- bash
- [python3](https://www.python.org/)
- [awscli](https://aws.amazon.com/cli/)
- [boto3](https://aws.amazon.com/sdk-for-python/)
- [docker](https://www.docker.com/)
- [git](https://git-scm.com/)

## Download

Clone using git:
```
git clone --recurse-submodules https://github.com/usi-verification-and-security/smts-smtcomp-aws.git
```
(It should work even without option `--recurse-submodules` though.)

## Run Script

Before running scripts that interact with AWS resources, it is necessary to create an account and set up your credentials on your local machine. For this, follow the link above with the instructions given by the organizers.

We provide `runme` Bash script which should provide all functionality necessary for building and uploading images to AWS.
Simply run
```
./runme <mode>
```
where `<mode>` is either `cloud` or `parallel`.
Except for uploading the images, it will also run the solver on the AWS cloud on a sample benchmark at the end, to ensure that everything works.

Note that the script will shut down the AWS resources but will not delete them (neither from AWS nor from your local machine).

### Internal script

Script `runme` is just a wrapper of internal `do.sh` script which also allows to do only some particular steps of the procedure.
However, using this script should be necessary only for the developers of this repository.

The usage of the script is
```
bash do.sh <tool> <domain> <action> [options]
```
The script can be used also for `mallob` SAT solver.
Assuming that the user wants to use our SMTS solver, the usage is
```
bash do.sh smts smt <action> [options]
```
See the output of `bash do.sh` for available actions and options.
The actions `docker-*` are related to managing docker images on your local machine.
The actions `infra-*` are related to managing docker images on your AWS account. Switching between the parallel and the cloud track is done via `-P` option.

To delete remote AWS resources, use action `infra-delete`.
This is useful for example when, after uploading, one wants to switch from one track to another.
Example sequence of actions and options: `infra-all`, then `infra-delete`, then `infra-all -P` (first cloud track, then parallel track).

To clean up, that is, to wipe all temporary files, docker images and also remote AWS resources, use action `clean`. It also implies `infra-delete`.
It is also possible to use `-c` option in combination with an action.

To _not_ shut down the AWS resources at the end, that is, to keep them alive, use `-k` option (cloud track only).
Later, one should use action `infra-shutdown`.
Note that accessing files in the S3 bucket is possible even without keeping alive, that is, even after shutting down.
