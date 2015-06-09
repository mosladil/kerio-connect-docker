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
	docker build -t ${CONNECT_NAME}:${CONNECT_VERSION}.${CONNECT_BUILD} .
}

function removeContainer {
	echo "Cleaning builded image..."
	docker rmi -f ${IMAGE} &>/dev/null
}

function removeStore {
	read -r -p "Do you really want to remove store, license and settings? [y/N] " response
 	if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]; then
 		echo "Cleaning store and settings..."
		rm -rf ${THIS_HOME}/data/*
		for DIR in ${THIS_HOME}/data/dbSSL ${THIS_HOME}/data/license ${THIS_HOME}/data/settings ${THIS_HOME}/data/sslcert ${THIS_HOME}/data/store; do
			mkdir -p ${DIR}
			touch ${DIR}/.empty
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

	docker run -d ${PORTS} \
		-v ${THIS_HOME}/data:/data \
		${IMAGE} &>/dev/null

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
	docker run -d -P ${IMAGE} &>/dev/null
}

function stopContainer {
	CONTAINER_ID=$(docker ps | grep ${IMAGE}| awk '{print $1}')

	if [ -z "${CONTAINER_ID}" ]; then
		echo "No running container found..."
		[ "$1" == "IGNORE_STATE" ]  && return || exit 1
	fi

	echo -n "Stopping CONTAINER_ID=${CONTAINER_ID}..."
	docker stop ${CONTAINER_ID} &>/dev/null
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

	echo "Server started and listening on:"
	echo "	docker exec -ti ${CONTAINER_ID} bash"

	DOCKER_MACHINE=$(docker-machine url | cut -f2 -d:)
	if [ ! -z ${DOCKER_MACHINE} ]; then
		echo "	http:${DOCKER_MACHINE}:${ADMIN_PORT}/admin"
	fi
	
	waitForAdministration
	echo ""
}

function waitForAdministration {
	echo "Waiting for server comming live:"
	echo -n "	"
	STARTING=true
	while ${STARTING}; do
		nc -w 1 $(echo ${DOCKER_MACHINE} | cut -f3 -d/) ${ADMIN_PORT} &>/dev/null
		if [ "$?" == 0 ]; then
			STARTING=false
			echo "done!"
		else
			echo -n .
			sleep 1
		fi
	done
}

function checkDockerExecutables {
	commandExists docker
	commandExists docker-machine
}

function commandExists () {
	type "$1" &> /dev/null ;
	if [ "$?" == 1 ]; then
		echo "Missing command $1. Please, install it first!"
		exit 1
	fi
}

checkDockerExecutables