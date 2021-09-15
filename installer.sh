#!/bin/bash

# (c) Aaron Gensetter, 2020

<< 'TODO'
  POSTGRES -> port free chekcer, display msg (make function?)
TODO

if [[ $UID -ne 0 ]]; then
  echo "You habe to be root"
  exit 1
fi

readonly F_RED=$(tput setaf 1)
readonly F_GREEN=$(tput setaf 2)
readonly F_YELLOW=$(tput setaf 3)
readonly F_BLUE=$(tput setaf 4)
readonly F_RESET=$(tput sgr0)

readonly VERSIONS=(
  postgres
  mariadb
  mysql
)

SILENT=false

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

# POSTGRES
postgres() {
  read -p "Enter a name: " NAME
  read -p "Enter a port (or auto): " PORT
  read -p "Enter a superuser name: " SUPERUSER
  read -s -p "Enter a password: " PASSWORD; echo
  read -p "Enter a database name: " DATABASE

  # validate NAME
  if [[ $NAME == "" ]]; then messages "error" "Name not set"; exit 1; fi
  if [[ $(docker ps -aqf "name=${NAME}" | wc -l) -ne 0 ]]; then messages "error" "A container with this name exists"; exit 1; fi
  # validate PORT
  if [[ $PORT == "" ]]; then messages "error" "Port not set"; exit 1; fi
  if [[ $PORT == "auto" ]]; then PORT=0; fi
  if [[ ( $(ss -tulpn | grep ":${PORT} " | wc -l) -ge 0 ) && $PORT -ne 0 ]]; then messages "error" "Port is already in use"; exit 1; fi
  if [[ $PORT -lt 0 || $PORT -gt 65535 ]]; then messages "error" "Port not in the valid range"; exit 1; fi
  # validate PASSWORD
  if [[ $PASSWORD == "" ]]; then messages "error" "Password not set"; exit 1; fi
  # validate DATABASE
  if [[ $DATABASE == "" ]]; then messages "error" "Database not set"; exit 1; fi
  # validate SUPERUSER
  if [[ $SUPERUSER == "" ]]; then messages "error" "Superuser not set"; exit 1; fi

  ID=$(docker run -d --name $NAME -p $PORT:5432 -e POSTGRES_PASSWORD=$PASSWORD -e POSTGRES_DB=$DATABASE -e POSTGRES_USER=$SUPERUSER postgres:latest)

  echo $ID
  # select port that is given
}
#MARIADB
mariadb() {
  echo "mariadb"
}
#MYSQL
mysql() {
  echo "mysql"
}

######################################
# SCRIPT
######################################

clear

echo "Select a database."
select opt in ${VERSIONS[@]}; do
  case $opt in
    "postgres")
      postgres
      exit 0
    ;;
    "mariadb")
      mariadb
      exit 0
    ;;
    "mysql")
      mysql
      exit 0
    ;;
    *)
      echo "try again"
   ;;
  esac
done
exit 0
