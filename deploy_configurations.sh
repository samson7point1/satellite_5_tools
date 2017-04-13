#!/bin/bash

# This script deploys all configuration channels to all subscribed systems

/bin/logger -t satellite ": job start [$0]"


source /var/satellite/maintenance/scrits/.satenv

SCRIPT_DIR="/var/satellite/maintenance/scripts"
API_SCRIPT="${SCRIPT_DIR}/spacewalk-api-custom --server=$SATELLITE_SERVER --user=$SATELLITE_LOGIN --password=$SATELLITE_PASSWORD"
TERM=xterm
export TERM LFSC API_SCRIPT

cd $SCRIPT_DIR

# Web API Call Prep
. ./automation-api-prep.sh 
CAT=prevention
DESC="Deploying Configurations from the Satellite"
TIMESAVED=5

# Local log definition
SHORTLOG=`basename $0`.log

echo "Config channel deployment executed at `date`" >> $SHORTLOG

CONFIG_CHANNELS="
rhel-base-config
rhel7-base-config
rhel6-base-config
rhel5-base-config
sap-base-config
SAP-etc-services
oracle-db-base-config
"

for CC in `echo $CONFIG_CHANNELS`; do

   # Deploy channel to all subscribed systems immediately
   RESULT=`$API_SCRIPT configchannel.deployAllSystems "%session%" "$CC"`
   if [[ -z `echo $RESULT | grep " = '1'"` ]]; then
      echo "An error occured when attempting to deploy configuration channel [$CC]"
      echo "Error Text: [$RESULT]"
      echo ""
      NOTES="An error occured: $RESULT"
   fi


done


# Send Event
END=`date "+%Y-%m-%d %H:%M:%S"`
if [[ -z $NOTES ]]; then
   SUCCESS=true
   /usr/bin/curl -k -X POST --form "origin_hostname=$ORIGIN" --form "target_hostname=$TARGET" --form "processname=$PNAME" --form "triggeredby=$TB" --form "category=$CAT" --form "description=$DESC" --form "target_ip=$TARGETIP" --form "timesaved=$TIMESAVED" --form "datestarted=$START" --form "datefinished=$END" --form "success=$SUCCESS" --user ${API_USER}:${API_PASS} $API_URL 2>&1 | > /dev/null
#### END API CALL ####
else
   SUCCESS=false
   /usr/bin/curl -k -X POST --form "origin_hostname=$ORIGIN" --form "target_hostname=$TARGET" --form "processname=$PNAME" --form "triggeredby=$TB" --form "category=$CAT" --form "description=$DESC" --form "target_ip=$TARGETIP" --form "timesaved=$TIMESAVED" --form "datestarted=$START" --form "datefinished=$END" --form "success=$SUCCESS" --form "notes=$NOTES" --user ${API_USER}:${API_PASS} $API_URL 2>&1 | > /dev/null
fi


/bin/logger -t satellite ": job end [$0]"
exit

