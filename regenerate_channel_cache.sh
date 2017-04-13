#!/bin/bash

CHANNEL=$1
echo "Attempting to regenerate the Satellite's YUM cache for $CHANNEL"
echo "Return code 1 indicates success."


source /var/satellite/maintenance/scrits/.satenv

SCRIPT_DIR="/var/satellite/maintenance/scripts"
API_SCRIPT="${SCRIPT_DIR}/spacewalk-api-custom --server=$SATELLITE_SERVER --user=$SATELLITE_LOGIN --password=$SATELLITE_PASSWORD"
TERM=xterm
export TERM

cd $SCRIPT_DIR

$API_SCRIPT channel.software.regenerateYumCache "%session%" $CHANNEL
exit
