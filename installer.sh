#!/bin/bash

# https://github.com/Spacelord09/mcserver-deploy

# Aaron Gensetter, 2021

# TODO 
# 	- check if other server usees port
#	- implement -y
#	- Plugin selecter

# Text Format
F_RED=$(tput setaf 1)
F_GREEN=$(tput setaf 2)
F_YELLOW=$(tput setaf 3)
F_BLUE=$(tput setaf 4)
F_RESET=$(tput sgr0 )

PACKAGES=(
	jq
	openjdk-16-jre-headless
	screen
	wget
	sudo
)

install_packages() {
	echo "Installing needed packages"
	for PACKAGE in ${PACKAGES[@]}; do
		dpkg -s $PACKAGE  &> /dev/null
		if [[ $? -ne 0 ]]; then
			echo "${F_RED}${PACKAGE} not found${F_RESET}"
			echo "${F_YELLOW}installing $PACKAGE...${F_RESET}"
			apt install $PACKAGE -y &> /dev/null
			if [[ $? -ne 0 ]]; then
				echo "${F_RED}installation failed, \"${PACKAGE}\" not found${F_RESET}"
				echo "${F_YELLOW}try \"sudo apt update\"${F_RESET}"
				exit 1
			fi
		fi
	done

	clear 
}

check_args() {
	if [[ $# -lt 1 ]]; then
		echo "Please use $0 --help"
		exit 1
	fi

    for ARG in $@; do
		case $ARG in
		# HELP
		--help|-h)
			echo "HELP - Commands of ${0}"
			echo "-----------"
			echo "--help: prints Help"
			echo "--show-versions: prints all possible versions of Minecraft"
			echo "-----------"
			echo "-ram: sets RAM (512 - 8192)MB (default= 1024)MB"
			echo "-name: sets name (default= srv1)"
			echo "-version: sets version (default= latest)"
			echo "-port: sets port (default= 25565)"
			echo "-y ?"
			exit 0
		;;
		# SHOW VERSION
		--show-versions|-mcv)
			echo "Listing all PaperMC Versions."
			echo "LATEST: $(echo $PAPERMC_VERSION_LATEST | sed -r 's/["]+//g')"
			for VERSION in ${PAPERMC_VERSIONS[@]}; do
				echo $(echo "-" $VERSION | sed -r 's/["]+//g')
			done
			exit 0
		;;
		-y)
			YES=true
		;;
		# RAM
		-ram=*)
			TEMP_RAM=$(echo $ARG | sed 's/-ram=//')

			if [[ $TEMP_RAM != "" ]] && [[ $TEMP_RAM -gt 511 ]] && [[ $TEMP_RAM -lt 8193 ]]; then
				RAM=$TEMP_RAM
			else
				echo "${F_RED}RAM not correct, set to default. ${RAM}MB${F_RESET}"
			fi
		;;
		# NAME
		-name=*)
			TEMP_NAME=$(echo $ARG | sed 's/-name=//')
			if [[ $TEMP_NAME != "" ]]; then
				NAME=$TEMP_NAME
			else 
				echo "${F_RED}NAME not correct, set to default. ${NAME}${F_RESET}"
			fi
		;;
		# VERSION
		-version=*)
			TEMP_VERSION=$(echo $ARG | sed 's/-version=//')
			FOUND=0

			for MCVERSION in ${PAPERMC_VERSIONS[@]}; do
				if [[ ${TEMP_VERSION} == $(echo "${MCVERSION}" | sed -r 's/["]+//g') ]]; then
					FOUND=1
					break
				fi
			done

			if [[ $FOUND -eq 1 ]]; then
				VERSION=$TEMP_VERSION
			else
				echo "${F_RED}Version not found, set to default. ${VERSION}${F_RESET}"
			fi
		;;
		# NAME
		-port=*)
			TEMP_PORT=$(echo $ARG | sed 's/-port=//')
			if [[ $TEMP_PORT != "" ]] && [[ $TEMP_PORT -gt 1023 ]] && [[ $TEMP_PORT -lt 65536 ]]; then
				PORT=$TEMP_PORT
			else 
				echo "${F_RED}PORT not correct, set to default. ${PORT}${F_RESET}"
			fi
		;;
		*);;
		esac
    done
}

create_service() {
	FILE="/etc/systemd/system/mc-${NAME}.service"

	echo -e "[Unit]" >> $FILE
	echo -e "Description=Minecraft Server: mc-$NAME" >> $FILE
	echo -e "After=network.target" >> $FILE
	echo -e "" >> $FILE
	echo -e "[Service]" >> $FILE
	echo -e "WorkingDirectory=/opt/mc_servers/mc-${NAME}" >> $FILE
	echo -e "User=${USERNAME}" >> $FILE
	echo -e "Group=${USERNAME}" >> $FILE
	echo -e "Restart=always" >> $FILE
	echo -e "ExecStart=screen -DmS mc-${NAME} java -Xmx${RAM}M -jar server.jar nogui" >> $FILE
	#echo -e "ExecStop=SCRIPT" >> $FILE
	echo -e "" >> $FILE
	echo -e "[Install]" >> $FILE
	echo -e "WantedBy=multi-user.target" >> $FILE

	echo "${F_GREEN}Service created${F_RESET}"
}

create_enviroment() {
	if [[ -d /opt/mc_servers/mc-$NAME ]]; then
		echo "${F_RED}This server exists! (${NAME})${F_RESET}"
		exit 1
	fi

	if ! id "${USERNAME}" &>/dev/null; then
		useradd -m -d /opt/mc_servers $USERNAME -s /bin/bash
		echo "${F_GREEN}User \"${USERNAME}\" was created${F_RESET}"
	fi

	chown $USERNAME:$USERNAME /opt/mc_servers -R
	sudo -u $USERNAME mkdir /opt/mc_servers/mc-$NAME
	echo "${F_GREEN}Created new directory for Server mc-${NAME}${F_RESET}"
	cd /opt/mc_servers/mc-$NAME
}

install() {
	echo "${F_GREEN}Creating server \"${NAME}\" with version \"${VERSION}\" with \"${RAM}\"MB of memory.${F_RESET}"
	echo "${F_GREEN}downloading ${VERSION}...${F_RESET}"

	echo "VRESION: $VERSION"
	wget https://papermc.io/api/v1/paper/$VERSION/latest/download -O server.jar --show-progress -q
	echo "eula=true" > eula.txt # accept eula
	echo "server-port=${PORT}" > server.properties # set port

	create_service

	chown $USERNAME:$USERNAME /opt/mc_servers -R
	systemctl enable mc-$NAME
	systemctl start mc-$NAME
}

##################
# Script    	 #
##################

# check if user is root
if [[ $UID -ne 0 ]]; then
	echo "${F_RED}You have to be root, to execute this part!${F_RESET}"
	echo "${F_RED}try \"sudo ${0}\"${F_RESET}"
	exit 1
fi

install_packages

PAPERMC_VERSIONS=$(curl -s https://papermc.io/api/v1/paper | jq '.versions |. []')
PAPERMC_VERSION_LATEST=$(curl -s https://papermc.io/api/v1/paper | jq '.versions |. [0]' | sed -r 's/["]+//g')
# Standard stuff
YES=false
RAM=1024
NAME="srv1"
VERSION=$PAPERMC_VERSION_LATEST
USERNAME="mc-user"
PORT=25565

check_args $*

create_enviroment
install

exit 0
