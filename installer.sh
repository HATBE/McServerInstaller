#!/bin/bash

# check out: https://github.com/Spacelord09/mcserver-deploy
# Aaron Gensetter, 2021

<< 'TODO'
    L 204 -> create stop script
    implement plugin downloader
TODO

if [[ $UID -ne 0 ]]; then
	echo "${F_RED}You have to be root, to execute this script!${F_RESET}"
	echo "${F_RED}try \"sudo ${0}\"${F_RESET}"
	exit 1
fi

readonly MAX_RAM=8192
readonly MIN_RAM=512

# Text Format
readonly F_RED=$(tput setaf 1)
readonly F_GREEN=$(tput setaf 2)
readonly F_YELLOW=$(tput setaf 3)
readonly F_BLUE=$(tput setaf 4)
readonly F_RESET=$(tput sgr0)

readonly SRV_DIR="/opt/mc_servers"
readonly PACKAGES=(
	jq
	openjdk-16-jre-headless
	screen
	wget
	sudo
    curl
)

YES=false
SHOW_VERSIONS=false
SILENT=false

RAM=1024
NAME="srv1"
USERNAME="mc-user"
PORT=25565
VERSION="1.17.1"

usage() {
    echo "Usage: ${0} [-r RAM] [-n NAME] [-v VERSION] [-p PORT]"
    echo "-----------"
    echo "--help:           prints help"
    echo "--show-versions:  prints all possible versions of minecraft"
    echo "--silent;         no output to concsole"
    echo "-----------"
    echo "-r:               sets RAM (512 - 8192)MB (default= 1024)MB"
    echo "-n:               sets name (default= srv1)"
    echo "-v:               sets version (default= latest)"
    echo "-p:               sets port (default= 25565)"
    echo "-y:               dont ask questions"
    exit 1
}

messages() {
    if $SILENT; then
        return
    fi
    local MODE=$1
    shift
    case "${MODE}" in
        error) echo "${F_RED}[Error]: ${F_RESET}${@}!" >&2 ;;
        success) echo "${F_GREEN}[Success]: ${F_RESET}${@}" ;;
        info) echo "${F_BLUE}[Info]: ${F_RESET}${@}" ;;
        warn) echo "${F_YELLOW}[Warn]: ${F_RESET}${@}" ;;
        *) echo "${@}" ;;
    esac
}

show-versions() {
    messages 'info' 'Listing all PaperMC versions.'
    messages 'info' "Latest version: \"$(echo $PAPERMC_VERSION_LATEST | sed -r 's/["]+//g')\""
    for VERSION in ${PAPERMC_VERSIONS[@]}; do
        echo "- \"$(echo $VERSION | sed -r 's/["]+//g')\""
    done
    exit 0
}

install_packages() {
    local COUNT=0
    messages 'info' "Searching needed packages"
    for PACKAGE in ${PACKAGES[@]}; do
        dpkg -s $PACKAGE &> /dev/null
        if [[ $? -ne 0 ]]; then
            COUNT=$((COUNT++))
            messages 'warn' "\"${PACKAGE}\" not found"
            messages 'info' "installing \"${PACKAGE}\"..."
            apt install $PACKAGE -y &> /dev/null
            if [[ $? -ne 0 ]]; then
                messages 'error' "Installation of \"${PACKAGE}\" failed"
                messages 'info' "try: sudo apt update"
                exit 1
            fi
            messages 'success' "Installation of \"${PACKAGE}\" succeeded"
        fi
    done

    if [[ $COUNT -eq 0 ]]; then
        messages 'success' "Everithing up to date"
    else
        messages 'success' "Installed \"${COUNT}\" packages"
    fi
}

check_options() {
    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    while getopts r:n:v:p:-:y OPTION; do
        case ${OPTION} in
            -)
                case $OPTARG in
                    silent) SILENT=true ;;
                    help) usage ;;
                    show-versions) SHOW_VERSIONS=true ;;
                esac
            ;;
            r) RAM=$OPTARG ;;
            n) NAME=$OPTARG ;;
            v) VERSION=$OPTARG ;;
            p) PORT=$OPTARG ;;
            y) YES=true ;;
            *) usage ;;
        esac
    done
}

validate() {
    if [[ $RAM -lt $MIN_RAM || $RAM -gt $MAX_RAM ]]; then
        messages 'error' "Please use RAM in a range of \"${MIN_RAM}MB\" and \"${MAX_RAM}MB\""
        exit 1
    fi

    if [[ -d $SRV_DIR/mc-$NAME ]]; then
        messages 'error' "The Server \"${NAME}\" already exists"
        exit 1
    fi

    check_port
    check_version
}

create_environment() {
    if ! id "${USERNAME}" &>/dev/null; then
		useradd -m -d $SRV_DIR $USERNAME -s /bin/bash
		messages 'info' "User \"${USERNAME}\" was created" 
	fi

    chown $USERNAME:$USERNAME $SRV_DIR -R
	cd $SRV_DIR
}

check_version() {
    local FOUND=false

    for MCVERSION in ${PAPERMC_VERSIONS[@]}; do
        if [[ ${VERSION} == $(echo "${MCVERSION}" | sed -r 's/["]+//g') ]]; then
            FOUND=true
            break
        fi
    done

    if ! $FOUND; then
        messages 'warn' "version \"${VERSION}\" not found, default version: \"$PAPERMC_VERSION_LATEST\""
        VERSION=$PAPERMC_VERSION_LATEST
    fi
}
check_port() {
	if [[ -d $SRV_DIR ]]; then
		cd $SRV_DIR
		local SRVS=$(ls) # -d *

		for SRV in ${SRVS}; do
			cd $SRV
			local PORT_SELECTER=$(cat server.properties | grep server-port= | sed 's/server-port=//')

			if [[ $PORT_SELECTER == $PORT  ]]; then
				messages 'error' "Port \"${PORT}\" already in use."
				exit 1
			fi

			cd $SRV_DIR
		done
	fi
}

create_service() {
	local FILE="/etc/systemd/system/mc-${NAME}.service"

	echo -e "[Unit]" >> $FILE
	echo -e "Description=Minecraft Server: mc-$NAME" >> $FILE
	echo -e "After=network.target" >> $FILE
	echo -e "" >> $FILE
	echo -e "[Service]" >> $FILE
	echo -e "WorkingDirectory=${SRV_DIR}/mc-${NAME}" >> $FILE
	echo -e "User=${USERNAME}" >> $FILE
	echo -e "Group=${USERNAME}" >> $FILE
	echo -e "Restart=always" >> $FILE
	echo -e "ExecStart=screen -DmS mc-${NAME} java -Xmx${RAM}M -jar server.jar nogui" >> $FILE
	#echo -e "ExecStop=SCRIPT" >> $FILE
	echo -e "" >> $FILE
	echo -e "[Install]" >> $FILE
	echo -e "WantedBy=multi-user.target" >> $FILE

    messages 'success' "Service \"mc-${NAME}.service\" created"
}

create_server() {
    messages 'info' "Creating server \"${NAME}\" with version \"${VERSION}\" and \"${RAM}MB\" of memory, on port \"${PORT}\""

    if ! $YES; then
        read -p "Do you want to create this Server? (y/n): " READ
        if ! [[ $READ =~ [yjYJ] ]]; then
            messages 'error' "exiting"
            exit 1 
        fi
    fi

    sudo -u $USERNAME mkdir $SRV_DIR/mc-$NAME
    cd $SRV_DIR/mc-$NAME
	messages 'success' "Created directory \"${SRV_DIR}/mc-${NAME}\""
    messages 'info' "downloading \"${VERSION}\""

    wget https://papermc.io/api/v1/paper/$VERSION/latest/download -O server.jar --show-progress -q
    echo "eula=true" > eula.txt # accept eula
    echo "server-port=${PORT}" > server.properties # enter the user port into server config

    chown $USERNAME:$USERNAME $SRV_DIR -R

    create_service

	systemctl enable mc-$NAME &> /dev/null
	systemctl start mc-$NAME &> /dev/null
    
    if [[ $? -ne 0 ]]; then
        messages 'success' "Service \"mc-${NAME}.service\" started"
    fi
}

# SCRIPT

check_options $@
install_packages

PAPERMC_VERSIONS=$(curl -s https://papermc.io/api/v1/paper | jq '.versions |. []')
PAPERMC_VERSION_LATEST=$(curl -s https://papermc.io/api/v1/paper | jq '.versions |. [0]' | sed -r 's/["]+//g')

# this function need to stay here (it uses packages and the papermc versions)
if $SHOW_VERSIONS; then
    show-versions
    exit 0
fi

validate
create_environment
create_server

exit 0
