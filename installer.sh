#!/bin/bash

#TODO: 
# - make stop script
# - check if name exists
# - code cleanup
# - check if port is used by other server

##################
# functions 	 #
##################

PACKAGES=(
	jq
	openjdk-16-jre-headless
	screen
	wget
	sudo
)

# Text Format
F_RED=$(tput setaf 1)
F_GREEN=$(tput setaf 2)
F_YELLOW=$(tput setaf 3)
F_BLUE=$(tput setaf 4)
F_RESET=$(tput sgr0 )

install_packages() {
	echo "Installing needed packages"
	# check for installed packages
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
}

check_args() {
	for ARG in $*; do
		if [[ $ARG == "--help" ]] || [[ $ARG == "-h" ]]; then
			echo "HELP"
			echo "-----------"
			echo "USAGE: ${0} [version] [name] ([ram in mb])"
			echo "	> Default ram = 1024MB"
			echo 
			echo "${0} --help"
			echo "	> shows help"
			echo "${0} --show-versions"
			echo "	> shows all versions of PaperMC"
			exit 0
		elif [[ $ARG == "--show-versions" ]]; then
			echo "Listing all PaperMC Versions."
			API=$(curl -s https://papermc.io/api/v1/paper | jq '.versions |. []')
			for VERSION in ${API[@]}; do
				echo $VERSION
			done
			exit 0
		fi
	done
}

install() {
	API=$(curl -s https://papermc.io/api/v1/paper | jq '.versions |. []')
	SELECTED_VERSION=$1
	NAME=$2
	RAM=$3
	USERNAME=$4

	FOUND=0
	for VERSION in ${API[@]}; do
		if [[ ${SELECTED_VERSION} == $(echo "${VERSION}" | sed -r 's/["]+//g') ]]; then
			FOUND=1
			echo "Version ${SELECTED_VERSION} selected"
			break
		fi
	done

	if [[ $FOUND -ne 1 ]]; then
		echo "${F_RED}Version \"${SELECTED_VERSION}\" not found${F_RESET}"
		exit 1
	fi

	echo "Creating server \"${NAME}\" with version \"${SELECTED_VERSION}\" with \"${RAM}\"MB of memory."

	echo "downloading ${SELECTED_VERSION}..."

	wget https://papermc.io/api/v1/paper/$SELECTED_VERSION/latest/download -O server.jar --show-progress -q
	echo "eula=true" > eula.txt # accept eula

	# Service
	create_service $NAME $SELECTED_VERSION $RAM $USERNAME

	chown $USERNAME:$USERNAME /opt/mc_servers -R

	systemctl enable mc-$NAME
	systemctl start mc-$NAME
}

create_service() {
	NAME=$1
	RAM=$3
	USER=$4
	FILE="/etc/systemd/system/mc-${NAME}.service"

	echo -e "[Unit]" >> $FILE
	echo -e "Description=Minecraft Server: mc-$NAME" >> $FILE
	echo -e "After=network.target" >> $FILE
	echo -e "" >> $FILE
	echo -e "[Service]" >> $FILE
	echo -e "WorkingDirectory=/opt/mc_servers/mc-${NAME}" >> $FILE
	echo -e "User=${USER}" >> $FILE
	echo -e "Group=${USER}" >> $FILE
	echo -e "Restart=always" >> $FILE
	echo -e "ExecStart=screen -DmS mc-${NAME} java -Xmx${RAM}M -jar server.jar nogui" >> $FILE
	#echo -e "ExecStop=SCRIPT" >> $FILE
	echo -e "" >> $FILE
	echo -e "[Install]" >> $FILE
	echo -e "WantedBy=multi-user.target" >> $FILE
}

create_enviroment() {

	USERNAME=$1
	NAME=$2

	if ! id "${USERNAME}" &>/dev/null; then
		useradd -m -d /opt/mc_servers $USERNAME -s /bin/bash
		echo "User \"${USERNAME}\" wurde erstellt"
	fi

	chown $USERNAME:$USERNAME /opt/mc_servers -R
	sudo -u $USERNAME mkdir /opt/mc_servers/mc-$NAME
	cd /opt/mc_servers/mc-$NAME
}

##################
# Script Start	 #
##################

# check if user is root
if [[ $UID -ne 0 ]]; then
	echo "${f_RED}you have to be root to execute this script!${F_RESET}"
	exit 1
fi

install_packages
clear
check_args

# check if arguments matches
if [[ $# -lt 2 ]] || [[ $# -gt 3 ]]; then
	echo "USAGE: ${0} [version] [name] ([ram in mb])"
	exit 1
fi

USERNAME="mc-user"
NAME=$2
VERSION=$1

create_enviroment $USERNAME $NAME

if [[ $3 != "" ]] && [[ $3 -gt 511 ]] && [[ $3 -lt 8193 ]]; then
	RAM=$3
else 
	echo "${F_YELLOW}Ram was set to default. (1024MB)${F_RESET}"
	RAM=1024
fi

install $VERSION $NAME $RAM $USERNAME

exit 0
