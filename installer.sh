#!/bin/bash

if [[ $UID -ne 0 ]]; then
	echo "you have to be root to execute this script!"
	exit 1
fi

PACKAGES=(
	jq
	openjdk-8-jre
	screen
)

install_packages() {
	# check for installed packages
	for PACKAGE in ${PACKAGES[@]}; do
		dpkg -s $PACKAGE  &> /dev/null
		if [[ $? -ne 0 ]]; then
			echo "installing $PACKAGE..."
			apt install $PACKAGE -y &> /dev/null
			if [[ $? -ne 0 ]]; then
				echo "installation failed, \"${PACKAGE}\" not found"
				exit 1
			fi
		fi
	done
}

install_paperjar() {
	API=$(curl -s https://papermc.io/api/v1/paper | jq '.versions |. []')
	SELECTED_VERSION=$1

	FOUND=0
	for VERSION in ${API[@]}; do
			if [[ ${SELECTED_VERSION} == $(echo "${VERSION}" | sed -r 's/["]+//g') ]]; then
			FOUND=1
			echo "Version ${SELECTED_VERSION} selected"
			break
			fi
		done

		if [[ $FOUND -ne 1 ]]; then
			echo "Version \"${SELECTED_VERSION}\" not found"
		exit 1
	fi

	NAME=$2
	if [[ $3 != "" ]] && [[ $3 -gt 512 ]] && [[ $3 -lt 8193 ]]; then
		RAM=$3
	else 
		echo "Ram was set to default. (1024MB)"
		RAM=1024
	fi

	echo "> Creating server \"${NAME}\" with version \"${SELECTED_VERSION}\" with \"${RAM}\"MB of memory."

	echo "downloading ${SELECTED_VERSION}..."

	wget https://papermc.io/api/v1/paper/$SELECTED_VERSION/latest/download -O paper-$SELECTED_VERSION.jar --show-progress -q
	echo "eula=true" > eula.txt

	echo "screen -S ${NAME} java -Xms${RAM}M -Xmx${RAM}M -jar paper-${SELECTED_VERSION}.jar" > start.sh
	chmod +x start.sh
}

##################
# Script Start	 #
##################

if [[ $# -lt 2 ]] || [[ $# -gt 3 ]]; then
	echo "USAGE: ${0} [version] [name] ([ram in mb])"
	exit 1
fi

install_packages
install_paperjar $1 $2 $3
