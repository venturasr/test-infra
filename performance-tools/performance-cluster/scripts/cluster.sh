#!/usr/bin/env bash

set -o errexit
set -o pipefail  # Fail a pipe if any
#set -x
export CURRENT_PATH="$PWD"
export DOCKER_IN_DOCKER_ENABLED="true"
export REPO_OWNER="kyma-project"
export REPO_NAME="kyma"
export CLOUDSDK_PROJECT="kyma-project"

source "${CURRENT_PATH}/scripts/library.sh"

if [ $# -lt "1" ]; then
        echo "Usage:  $0 --action (create or delete) --cluster-grade (production or development)"
        exit 1;
fi

POSITIONAL=()
while [[ $# -gt 0 ]]
do

    key="$1"

    case ${key} in
        --action)
            checkInputParameterValue "$2"
            ACTION="${2}"
            checkActionInputParameterValue "$2"
            shift # past argument
            shift # past value
        ;;
        --cluster-grade)
            checkInputParameterValue "$2"
            CLUSTER_GRADE="$2"
            checkClusterGradeInputParameterValue "$2"
            shift # past argument
            shift # past value
        ;;
        *)    # unknown option
            POSITIONAL+=("$1") # save it in an array for later
            shift # past argument
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters


export ACTION
export CLUSTER_GRADE

if [[ "${CLUSTER_GRADE}" == "" ]] || [[ "${ACTION}" == "" ]]; then
    shoutFail "--action and --cluster-grade required"
    exit 0
fi

shout "Cluster Grade ${CLUSTER_GRADE}"

if [[ "${INPUT_CLUSTER_NAME}" == "" ]]; then
    shoutFail "Environment INPUT_CLUSTER_NAME is required"
    exit 0
fi

if [[ ! -f "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
    shoutFail "Environment GOOGLE_APPLICATION_CREDENTIALS with service_account credetntials is required."
    exit 0
fi

shout "Directory ${GOPATH}/src/github.com/kyma-project/kyma does exists."

if [[ "${CLUSTER_GRADE}" == "development" ]] && [[ ! -d "${GOPATH}/src/github.com/kyma-project/kyma" ]]; then
    shoutFail "Directory ${GOPATH}/src/github.com/kyma-project/kyma does not exists."
    exit 0
fi

setupCluster() {

    set +o errexit
    source "scripts/kyma-gke-cluster.sh"
    set -o errexit

}

setupCluster

shout "${ACTION} finished with success"