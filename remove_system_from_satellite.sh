#!/bin/bash


source /var/satellite/maintenance/scrits/.satenv

SCRIPT_DIR="/var/satellite/maintenance/scripts"
API_SCRIPT="${SCRIPT_DIR}/spacewalk-api-custom --server=$SATELLITE_SERVER --user=$SATELLITE_LOGIN --password=$SATELLITE_PASSWORD"
TERM=xterm
export TERM

cd $SCRIPT_DIR

if [[ -z $1 ]]; then
   echo "Error: System name not provided."
   exit 1
fi

STBREMOVED=$1

ID=`$API_SCRIPT system.getId "%session%" "$STBREMOVED" | egrep "'id' =>" | head -1 | awk '{print $3}' | tr -d "'"`

if [[ -z $ID ]]; then
   echo "Error: System [$STBREMOVED] not found in Satellite."
   exit 2
else
   echo "Removing system [$STBREMOVED] from the Satellite."
   RESULT=`$API_SCRIPT system.deleteSystem "%session%" "$ID"`
   if [[ -n `echo $RESULT | grep " = '1'"` ]]; then
      echo "Success"
      exit 0
   else
      echo "Error: action resulted in [$RESULT]"
      exit 3
   fi
fi


exit


