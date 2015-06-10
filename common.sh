#!/bin/bash

CONNECT_NAME=$(grep 'ENV CONNECT_NAME' Dockerfile | awk {'print $3'})
CONNECT_VERSION=$(grep 'ENV CONNECT_VERSION' Dockerfile | awk {'print $3'})
CONNECT_BUILD=$(grep 'ENV CONNECT_BUILD' Dockerfile | awk {'print $3'})
CONNECT_HOME=$(grep 'ENV CONNECT_HOME' Dockerfile | awk {'print $3'})

THIS_HOME=$(pwd)
IMAGE=${CONNECT_NAME}:${CONNECT_VERSION}.${CONNECT_BUILD}

function printBanner {
	echo "**************************"
	echo " ${IMAGE}"
	echo "**************************"
}

function buildContainer {
	echo "Starting build..."
	docker build -t ${IMAGE} .
}

function removeContainer {
	readYes "Remove container"
	YES=$?

	if [ ${YES} == 0 ]; then
		echo "Cleaning builded image..."
		execute "docker rmi -f ${IMAGE}"
	else
		exit 1
	fi
}

function removeStore {
	readYes "Remove store, license and settings"
	YES=$?

	if [ ${YES} == 0 ]; then
 		echo "Cleaning store and settings..."
		execute "rm -rf ${THIS_HOME}/data/*"
		for DIR in ${THIS_HOME}/data/dbSSL ${THIS_HOME}/data/license ${THIS_HOME}/data/settings ${THIS_HOME}/data/sslcert ${THIS_HOME}/data/store; do
			execute "mkdir -p ${DIR}"
			execute "touch ${DIR}/.empty"
		done
	fi
}

function checkContainer {
	IS_RUNING=$(docker ps | grep ${IMAGE})
	if [ "$?" == 0 ]; then
		echo "Container info:"
		showContainerInfo
		exit 1
	fi

}

function startMappedContainer {
	checkContainer
	echo -n "Starting new container"

	if [ -e "${THIS_HOME}/data/mailserver.cfg" ]; then
		echo -n " using ports in mailserver.cfg..."
		EXPOSE=$(grep \"Port\" ${THIS_HOME}/data/mailserver.cfg | cut -d\< -f2 | cut -d\> -f2 | sort | uniq)
	else
		echo -n " using default ports..."
		EXPOSE=$(grep EXPOSE Dockerfile | awk '{$1=""; print $0}')
	fi

	for PORT in ${EXPOSE}; do
		PORTS="${PORTS}-p ${PORT}:${PORT} "
	done

	execute "docker run -d ${PORTS} \
		-v ${THIS_HOME}/data:/data \
		${IMAGE}"

	if [ "$?" == 0 ]; then
		echo "done!"
		showContainerInfo
	else
		echo "failed!"
		exit 1
	fi
}

function startContainer {
	echo -n "Starting new container..."
	checkContainer
	execute "docker run -d -P ${IMAGE}"
}

function stopContainer {
	CONTAINER_ID=$(docker ps | grep ${IMAGE}| awk '{print $1}')

	if [ -z "${CONTAINER_ID}" ]; then
		echo "No running container found..."
		[ "$1" == "IGNORE_STATE" ]  && return || exit 1
	fi

	echo -n "Stopping CONTAINER_ID=${CONTAINER_ID}..."
	execute "docker stop ${CONTAINER_ID}"
	[ "$?" == 0 ] && echo "done!" || "failed!"
}

function showContainerInfo {
	CONTAINER_ID=$(docker ps | grep ${IMAGE} | awk '{print $1}')
	IP=$(docker inspect --format='{{.NetworkSettings.IPAddress}}' ${CONTAINER_ID})
	TIMESTAMP=$(docker inspect --format='{{.State.StartedAt}}' ${CONTAINER_ID})
	ADMIN_PORT=$(docker port ${CONTAINER_ID} 4040 | cut -f2 -d':')

	echo "	ID -> ${CONTAINER_ID}"
	echo "	IP -> ${IP}"
	echo "	Started -> ${TIMESTAMP}"
	echo "Mapped ports:"

	while read PORT; do
		echo "	${PORT}"
	done < <(docker port ${CONTAINER_ID})

	if [ ! -z $DOCKER_HOST ]; then
		DOCKER_IP=$(echo ${DOCKER_HOST} | cut -d/ -f3 | cut -d: -f1)
	else
		DOCKER_IP="localhost"
	fi
	waitForAdministration

	echo "To enter console, type:"
	echo "	docker exec -ti ${CONTAINER_ID} bash"

}

function waitForAdministration {
	echo "Waiting for server comming live:"
	echo -n "	http://${DOCKER_IP}:${ADMIN_PORT}/admin "
	STARTING=true
	while ${STARTING}; do
		execute "nc -w 1 ${DOCKER_IP} ${ADMIN_PORT}"
		if [ "$?" == 0 ]; then
			STARTING=false
			echo "done!"
		else
			echo -n .
			sleep 1
		fi
	done

}

function checkRequirements {
	fileExists Dockerfile
	fileExists config/supervisord.conf

	checkExecutables
	checkDockerExecutables
}

function checkDockerExecutables {
	commandExists docker
}

function checkExecutables {
	commandExists nc
}

function commandExists {
	execute "type $1"
	if [ "$?" == 1 ]; then
		echo "Command '$1' not found!"
		exit 1
	fi
}

function fileExists {
	if [ ! -f "$1" ]; then
		echo "Cannot open '$1' (No such file or directory)"
		exit 1
	fi	
}

function readYes {
	MESSAGE=$1
	read -r -p "${MESSAGE}? [y/N] " RESPONSE
 	[[ ${RESPONSE} =~ ^([yY][eE][sS]|[yY])$ ]] && return 0 || return 1
}

function execute {
	[ ! -f ${DEBUG} ] && $1 ||  $1 &>/dev/null
}

checkRequirements
printBanner
