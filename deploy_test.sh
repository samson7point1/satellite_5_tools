#!/bin/bash

# This script deploys all configuration channels to all subscribed systems
/bin/logger -t satellite ": job start [$0]"


source /var/satellite/maintenance/scrits/.satenv

SCRIPT_DIR="/var/satellite/maintenance/scripts"
API_SCRIPT="${SCRIPT_DIR}/spacewalk-api-custom --server=$SATELLITE_SERVER --user=$SATELLITE_LOGIN --password=$SATELLITE_PASSWORD"
TERM=xterm
export TERM LFSC API_SCRIPT

cd $SCRIPT_DIR

SHORTLOG=`basename $0`.log

echo "Config channel deployment executed at `date`" >> $SHORTLOG

#$API_SCRIPT system.listSystems "%session%"
#$API_SCRIPT system.listActiveSystems "%session%"
SYSTEMLIST=`$API_SCRIPT system.listActiveSystems "%session%" | grep \'id\' | awk -F"'" '{print $4}' | sed ':a;N;$!ba;s/\n/,/g'`
echo $SYSTEMLIST

#SYSTEMLIST=1000010056

echo "$API_SCRIPT system.config.deployAll \"%session%\" \"[${SYSTEMLIST}]\" \"`date +%Y%m%dT%H:%M:%S`\""
#$API_SCRIPT system.config.deployAll "%session%" "[${SYSTEMLIST}]" "bless( do{\(my $o = '`date +%Y%m%dT%H:%M:%S`')}, 'Frontier::RPC2::DateTime::ISO8601' )"
#bless( do{\(my $o = '20151228T23:59:59')}, 'Frontier::RPC2::DateTime::ISO8601' )
#$API_SCRIPT satellite.getCertificateExpirationDate "%session%"


exit

#$API_SCRIPT channel.software.addPackages "%session%" "$UPDATE_CHANNEL" "[${ADDLIST}]"`
CONFIG_CHANNELS="
rhel6-base-config
rhel5-base-config
"

for CC in `echo $CONFIG_CHANNELS`; do

   # Deploy channel to all subscribed systems immediately
   RESULT=`$API_SCRIPT configchannel.deployAllSystems "%session%" "$CC"`
   if [[ -z `echo $RESULT | grep " = '1'"` ]]; then
      echo "An error occured when attempting to deploy configuration channel [$CC]"
      echo "Error Text: [$RESULT]"
      echo ""
   fi


done
/bin/logger -t satellite ": job end [$0]"
exit

