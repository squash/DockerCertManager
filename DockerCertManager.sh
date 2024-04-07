#!/bin/bash
# Variables you might change
MYHOME=~/DockerCertManager


# Check for required commands
declare -a COMMANDS=(openssl mkdir rm)
for COMMAND in ${COMMANDS[@]}; do
	which ${COMMAND}> /dev/null
	if [ $? != 0 ]; then
		echo "Required command ${COMMAND} missing or not in path."
		exit 1
	fi
done

COMMAND=$1

if [ "${COMMAND}" == "initca" ]
then
	if [ ! -d ${MYHOME} ]; then
		echo "Creating our storage area ${MYHOME}"
		mkdir -p ${MYHOME}
		if [ $? != 0 ]; then
			echo "Failed to create ${MYHOME}, exiting"
			exit 1
		fi
	fi



	if [ -e ${MYHOME}/ca.pem ] || [ -e ${MYHOME}/ca-key.pem ]
	then
		echo "I found an existing Certificate Authority. Unless you have a Really Good Reason, you don't want me to remove it."
		echo "If you do have a Really Good Reason, you will have to remove ${MYHOME}/ca-key.pem and ${MYHOME}/ca.pem yourself before I will create a new one."
		exit 1
	fi

	echo "Creating a new Certificate Authority"
	openssl genrsa -out ${MYHOME}/ca-key.pem
	openssl req -subj '/CN=docker' -new -x509 -days 9999 -key ${MYHOME}/ca-key.pem -out ${MYHOME}/ca.pem
	echo extendedKeyUsage = clientAuth,serverAuth > ${MYHOME}/extfile.cnf
	echo 01 > ${MYHOME}/ca.srl
	echo "Now you may create server and client keys."
	exit 0
fi
if [ "${COMMAND}" == "server" ]; then
	if [ ! -e ${MYHOME}/ca.pem ] || [ ! -e ${MYHOME}/ca-key.pem ]; then
		echo "Certificate Authority not found. You need to create that first with the 'initca' command."
		exit 1
	fi
	TARGET=$2
	if [ "${2}" == "" ]; then
		echo "TARGET argument required but missing."
		exit 1
	else
		TARGET=$2
		if [ -e ${MYHOME}/${TARGET}-server-key.pem ] || [ -e  ${MYHOME}/${TARGET}-server-cert.pem ]; then
			echo "I found an existing key for this server. If you have a Really Good Reason to replace it, you will need to remove it yourself."
			echo "The files are ${MYHOME}/${TARGET}-server-key.pem and ${MYHOME}/${TARGET}-server-cert.pem. Copy them to your server in /etc/docker sa ca.pem, cert.pem, and key.pem and chmod 400."
			echo "Configure your server's DOCKER_OPTS like so:  -H=0.0.0.0:4243 --tlsverify --tlscacert=/etc/docker/ca.pem --tlscert=/etc/docker/cert.pem --tlskey=/etc/docker/key.pem"
			exit 1
		fi

		echo "Creating Server Certificate For ${TARGET}"
		cp extfile.cnf extfile.server.cnf
		echo "subjectAltName=DNS:${TARGET}" >> extfile.server.cnf

		openssl genrsa -out  ${MYHOME}/${TARGET}-server-key.pem 2048
		openssl req -subj "/CN=${TARGET}" -new -key  ${MYHOME}/${TARGET}-server-key.pem -out  ${MYHOME}/${TARGET}-server.csr 
		openssl x509 -req -days 9999 -in  ${MYHOME}/${TARGET}-server.csr -CA ${MYHOME}/ca.pem -CAkey ${MYHOME}/ca-key.pem -out  ${MYHOME}/${TARGET}-server-cert.pem -extfile ${MYHOME}/extfile.server.cnf
		openssl rsa -in  ${MYHOME}/${TARGET}-server-key.pem -out  ${MYHOME}/${TARGET}-server-key.pem
		rm -f ${MYHOME}/${TARGET}-server.csr
		echo "Your server keys have been created: ."
		echo "The required files are ${MYHOME}/${TARGET}-server-key.pem, ${MYHOME}/${TARGET}-server-cert.pem, and ${MYHOME}/ca.pem"
		exit 0
	fi
fi
if [ "${COMMAND}" == "client" ]; then
	if [ ! -e ${MYHOME}/ca.pem ] || [ ! -e ${MYHOME}/ca-key.pem ]; then
		echo "Certificate Authority not found. You need to create that first with the 'initca' command."
		exit 1
	fi
	TARGET=$2
	if [ "${2}" == "" ]; then
		echo "TARGET argument required but missing."
		exit 1
	else
		TARGET=$2
	fi
	if [ -e ${MYHOME}/${TARGET}-client-key.pem ] || [ -e  ${MYHOME}/${TARGET}-client-cert.pem ]; then
		echo "I found an existing key for this client. If you have a Really Good Reason to replace it, you will need to remove it yourself."
		echo "The files are ${MYHOME}/${TARGET}-client-key.pem and ${MYHOME}/${TARGET}-client-cert.pem"
		exit 1
	fi
	cp extfile.cnf extfile.client.cnf
	echo "subjectAltName=DNS:${TARGET}" >> extfile.client.cnf

	openssl genrsa -out ${MYHOME}/${TARGET}-client-key.pem 2048
	openssl req -subj "/CN=${TARGET}" -new -key ${MYHOME}/${TARGET}-client-key.pem -out ${MYHOME}/${TARGET}-client.csr 
	openssl x509 -req -days 365 -in ${MYHOME}/${TARGET}-client.csr -CA ${MYHOME}/ca.pem -CAkey ${MYHOME}/ca-key.pem -out ${MYHOME}/${TARGET}-client-cert.pem -extfile ${MYHOME}/extfile.client.cnf
	openssl rsa -in  ${MYHOME}/${TARGET}-client-key.pem -out  ${MYHOME}/${TARGET}-client-key.pem
	rm -f ${MYHOME}//${TARGET}-client.csr
	echo "Your client keys have been created."
	echo "The required files are ${MYHOME}/${TARGET}-client-key.pem, ${MYHOME}/${TARGET}-client-cert.pem, and ${MYHOME}/ca.pem"
	echo "Copy them to your client in ~/.docker as key.pem, cert.pem, and ca.pem and chmod 400 to have them automatically used when you use --tlsverify"
	echo "Example connection: docker --tlsverify -H example.com:4243 ps"
	exit 0
fi

echo "Usage:"
echo -e "\t${0} [command] [target]"
echo "Commands:"
echo -e "\tinitca - creates a new Certificate Authority"
echo -e "\tserver [hostname] - Create a new Server key and Certificate for a given hostname"
echo -e "\tclient [name] - Create a new Client Certificate for a given client name"
echo
echo "https://github.com/squash/DockerCertManager"
exit

