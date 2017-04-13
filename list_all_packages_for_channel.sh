#!/bin/bash

# list all packages in a channel

# Define base API script string

source /var/satellite/maintenance/scrits/.satenv

API_SCRIPT="/var/satellite/maintenance/scripts/spacewalk-api-custom --server=$SATELLITE_SERVER --user=$SATELLITE_LOGIN --password=$SATELLITE_PASSWORD"

if [[ -z $1 ]]; then
   echo "Please provide a channel name"
   exit
fi

$API_SCRIPT channel.software.listAllPackages "%session%" $1

exit

