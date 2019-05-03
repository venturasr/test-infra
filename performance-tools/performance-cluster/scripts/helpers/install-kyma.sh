#!/usr/bin/env bash

#Description: Installs Kyma in a given GKE cluster
#
#Expected vars:
# - REMOTEENVS_IP_ADDRESS: static IP for remote env
# - GATEWAY_IP_ADDRESS: static IP for gateway
# - DOCKER_PUSH_REPOSITORY: name of the docker registry where images are pushed
# - KYMA_SOURCES_DIR: absolute path for kyma sources directory
# - DOCKER_PUSH_DIRECTORY: directory for docker images where it should be pushed
# - STANDARIZED_NAME: a variation of cluster name
# - REPO_OWNER: Kyma repository owner
# - REPO_NAME: name of the Kyma repository
# - CURRENT_TIMESTAMP: Current timestamp which is computed as $(date +%Y%m%d) 
# - DOMAIN: Combination of gcloud managed-zones and cluster name "${DNS_SUBDOMAIN}.${DNS_DOMAIN%?}"

source "${CURRENT_PATH}/scripts/library.sh"
function installKyma() {

	kymaUnsetVar=false

	for var in DOCKER_PUSH_REPOSITORY KYMA_SOURCES_DIR DOCKER_PUSH_DIRECTORY STANDARIZED_NAME REPO_OWNER REPO_NAME CURRENT_TIMESTAMP GOOGLE_APPLICATION_CREDENTIALS; do
    	if [ -z "${!var}" ] ; then
        	echo "ERROR: $var is not set"
        	kymaUnsetVar=true
    	fi
	done
	if [ "${kymaUnsetVar}" = true ] ; then
    	exit 1
	fi

	shout "Build Kyma-Installer Docker image"
	date
	if [[ "${CLUSTER_GRADE}" == "production" ]]; then
		KYMA_INSTALLER_IMAGE="${DOCKER_PUSH_REPOSITORY}${DOCKER_PUSH_DIRECTORY}:${CURRENT_TIMESTAMP}"
	else
		KYMA_INSTALLER_IMAGE="${DOCKER_PUSH_REPOSITORY}${DOCKER_PUSH_DIRECTORY}/${STANDARIZED_NAME}/${REPO_OWNER}/${REPO_NAME}:${CURRENT_TIMESTAMP}"
	fi
    export KYMA_INSTALLER_IMAGE
    shout "Kyma Installer Image: ${KYMA_INSTALLER_IMAGE}"
    source "${TEST_INFRA_PERFORMANCE_TOOLS_CLUSTER_SCRIPTS}/create-image.sh"

	KYMA_RESOURCES_DIR="${KYMA_SOURCES_DIR}/installation/resources"
	INSTALLER_YAML="${KYMA_RESOURCES_DIR}/installer.yaml"
	INSTALLER_CONFIG="${KYMA_RESOURCES_DIR}/installer-config-cluster.yaml.tpl"
	INSTALLER_CR="${KYMA_RESOURCES_DIR}/installer-cr-cluster.yaml.tpl"
	PROMTAIL_CONFIG_NAME=promtail-k8s-1-14.yaml


	#export DOMAIN=$(kubectl get cm net-global-overrides -n kyma-installer -o jsonpath='{.data.global\.ingress\.domainName}')
#export DNS_ZONE={YOUR_DNS_ZONE}

	shout "Apply Kyma config"
	date
	"${KYMA_SCRIPTS_DIR}"/concat-yamls.sh "${INSTALLER_YAML}" "${INSTALLER_CONFIG}" \
		| sed -e 's;image: eu.gcr.io/kyma-project/.*/installer:.*$;'"image: ${KYMA_INSTALLER_IMAGE};" \
		| sed -e "s/__REMOTE_ENV_IP__/${REMOTEENVS_IP_ADDRESS}/g" \
		| sed -e "s/__SKIP_SSL_VERIFY__/true/g" \
		| sed -e "s/__LOGGING_INSTALL_ENABLED__/true/g" \
		| sed -e "s/__PROMTAIL_CONFIG_NAME__/${PROMTAIL_CONFIG_NAME}/g" \
		| sed -e "s/__VERSION__/0.0.1/g" \
		| sed -e "s/__.*__//g" \
		| kubectl apply -f-

	waitUntilInstallerApiAvailable

	shout "Trigger installation"
	date

	kubectl config set-context "gke_${CLOUDSDK_CORE_PROJECT}_${CLOUDSDK_COMPUTE_ZONE}_${INPUT_CLUSTER_NAME}" --namespace=default

    sed -e "s/__VERSION__/0.0.1/g" "${INSTALLER_CR}"  | sed -e "s/__.*__//g" | kubectl apply -f-
	kubectl label installation/kyma-installation action=install
	"${KYMA_SCRIPTS_DIR}"/is-installed.sh --timeout 30m

}

function waitUntilInstallerApiAvailable() {
    shout "Waiting for Installer API"

	attempts=5
    for ((i=1; i<=attempts; i++)); do
        numberOfLines=$(kubectl api-versions | grep -c "installer.kyma-project.io")
        if [[ "$numberOfLines" == "1" ]]; then
            echo "API found"
            break
        elif [[ "${i}" == "${attempts}" ]]; then
            echo "ERROR: API not found, exit"
            exit 1
        fi

        echo "Sleep for 3 seconds"
        sleep 3
    done
}

function createConfigmap() {
    shout "Creating Configmap"

    # get kubeconfig
    # gcloud container clusters get-credentials "${INPUT_CLUSTER_NAME}" --zone="${CLOUDSDK_COMPUTE_ZONE}" --project="${CLOUDSDK_CORE_PROJECT}"
    # kubectl create configmap kyma-config --from-file="${HOME}/.kube/config"

}

installKyma

createConfigmap