#!/bin/bash


source /var/satellite/maintenance/scrits/.satenv

SCRIPT_DIR="/var/satellite/maintenance/scripts"
API_SCRIPT="${SCRIPT_DIR}/spacewalk-api-custom --server=$SATELLITE_SERVER --user=$SATELLITE_LOGIN --password=$SATELLITE_PASSWORD"
TERM=xterm
export TERM

cd $SCRIPT_DIR

echo $API_SCRIPT
exit
