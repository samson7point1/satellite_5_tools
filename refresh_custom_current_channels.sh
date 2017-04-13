#!/bin/bash

/bin/logger -t satellite ": job start [$0]"

# This script synchronizes a set of channels with the live RHN versions of those channels as of a certain point in time
# It is used to refresh the "current" channels AND its child chanels for "zero-day" type updates.


source /var/satellite/maintenance/scripts/.satenv
SCRIPT_DIR="/var/satellite/maintenance/scripts"
API_SCRIPT="${SCRIPT_DIR}/spacewalk-api-custom --server=$SATELLITE_SERVER --user=$SATELLITE_LOGIN --password=$SATELLITE_PASSWORD"
CLONE_BY_DATE="/usr/bin/spacewalk-clone-by-date"
BLACKLIST="${SCRIPT_DIR}/blacklist.txt"
KNOWN_SEV="${SCRIPT_DIR}/.known_severity"
LFSC="${SCRIPT_DIR}/.latest_name_and_id_${source_channel}_$$.txt"
KNOWN_REQ="${SCRIPT_DIR}/.known_requires"
TERM=xterm
export TERM LFSC API_SCRIPT

cd $SCRIPT_DIR

SHORTLOG=`basename $0`.log

echo "Update executed at `date`" >> $SHORTLOG

# CHANGEABLE VARIABLES

# This is the day of the week the Satellite normally synchronizes with RHN
NORMAL_SYNC_DAY=Sunday

# Frequency can be "SEMIANNUAL", "QUARTERLY", "MONTHLY", "ONDEMAND"
FREQUENCY=SEMIANNUAL
# Source to target channel pairs
STPS="
rhel-x86_64-server-7:rhel7-x86_64-custom_current
rhel-x86_64-server-6:rhel6-x86_64-custom_current
rhel-x86_64-server-5:rhel5-x86_64-custom_current
"

# Source to target cloned Child Channel Pairs
CCPS="
rhn-tools-rhel-x86_64-server-5:rhel5-x86_64-current_rhn_tools
rhn-tools-rhel-x86_64-server-6:rhel6-x86_64-current_rhn_tools
rhn-tools-rhel-x86_64-server-7:rhel7-x86_64-current_rhn_tools
rhel-x86_64-server-optional-6:rhel6-x86_64-custom_current-optional
rhel-x86_64-server-optional-7:rhel7-x86_64-custom_current-optional
rhel-x86_64-server-7-rhscl-1:rhel7-x86_64-software_collections
"

# If this script is NOT being run on the same day the satellite normally
# Synchronizes with RHN, run a full sync before attempting to update
# the channels.
DOW=`date +%A`

if [[ "$DOW" != "$NORMAL_SYNC_DAY" ]]; then
   echo "This job is being run on a [$DOW]"
   echo "The satellite normally synchronizes with RHN on [$NORMAL_SYNC_DAY]"
   echo "Synchronizing with RHN prior to updating channels."

   satellite-sync

fi


# Determine end/clone-to date
case $FREQUENCY in 

  SEMIANNUAL ) THIS_MONTH=`date +%m`
               N_THIS_MONTH=`date +%m | sed 's/^0//'`
               # Set the month of the first and second occurence
               FIRST=03
               SECOND=09

               # If the current month is greater than the month of the second occurrence and less or equal to 12
               # Then set the timestamp to the month of the second occurrence in the present year
               
               N_FIRST=`echo $FIRST | sed 's/^0//'`
               N_SECOND=`echo $SECOND | sed 's/^0//'`

               if [[ $N_THIS_MONTH -ge $N_SECOND ]] && [[ $N_THIS_MONTH -le 12 ]]; then
                  END_DATE="`date +%Y`-${SECOND}-01"
               # If the current month is less than the month of the first occurrence, set the timestamp to the
               # month of the second occurrence for the previous year
               elif [[ $N_THIS_MONTH -lt $N_FIRST ]]; then
                  END_DATE="$(echo `date +%Y` - 1 | /usr/bin/bc )-${SECOND}-01"
               # In all other situations set the timestamp to the month of the second occurrence in the current year
               else
                  END_DATE="`date +%Y`-${FIRST}-01"
               fi
               
               ;;

   QUARTERLY ) THIS_MONTH=`date +%m`
               case $THIS_MONTH in
                  01|02|03) END_DATE="`date +%Y`-01-01"
                            ;;
                  04|05|06) END_DATE="`date +%Y`-04-01"
                            ;;
                  07|08|09) END_DATE="`date +%Y`-07-01"
                            ;;
                  10|11|12) END_DATE="`date +%Y`-10-01"
                            ;;
                         *) echo "Error: date command returned an invalid result."
                            exit
                            ;;
               esac
               ;;
     MONTHLY ) END_DATE="`date +%Y-%m`-01"
               ;;
    ONDEMAND ) END_DATE="`date +%Y-%m-%d`"
               ;;
           * ) echo "Error: \"$FREQUENCY\" is an invalid setting for the variable FREQUENCY"
               exit
               ;;
esac

echo "Update Frequency is: $FREQUENCY"
echo "Channels will be synchronized with an end date of $END_DATE"
echo ""

# Process blacklist
for PN in `cat $BLACKLIST`; do
  BLSTRING="$BLSTRING,$PN"
done
BUFF=$BLSTRING
BLSTRING=`echo $BUFF | sed 's/^,//g;s/,$//g'`

# Process each source-target pair
for STP in $STPS; do

   # Split out the source and target channel
   SOURCE=`echo $STP | awk -F':' '{print $1}'`
   TARGET=`echo $STP | awk -F':' '{print $2}'`

   # Create a file to hold the latest name-to-id mapping for the Source channel
   LATEST=${SCRIPT_DIR}/.latest.$SOURCE

   #Create a flat database of the latest packages for this channel
   $API_SCRIPT channel.software.listLatestPackages "%session%" "$SOURCE" | egrep "{|}|'name' =>|'id' =>|'arch_label' =>" | tr -d "'," | sed ':a;N;$!ba;s/\n//g;s/{/\n/g;' | egrep -v "^[ \t]*$" | awk '{print $6"."$3","$9}' > $LATEST

   # Clone the parent channel
   echo ""
   echo "Cloning $TARGET from $SOURCE as of $END_DATE"
   $CLONE_BY_DATE -z -y -g --channels=${SOURCE} ${TARGET} --username $SATELLITE_LOGIN --password $SATELLITE_PASSWORD --to_date=${END_DATE} --blacklist="${BLSTRING}"


   # Programatically find the cloned child channels for this base channel
   CCL=`$API_SCRIPT channel.listSoftwareChannels "%session%" | sed "s/^[ \t]*//g" | sed ':a;N;$!ba;s/\n//g;s/{/\n/g;' | grep "'parent_label' => '${TARGET}'," | awk -F"'label' => '" '{print $2}' | awk -F"'" '{print $1}' | grep -v 'out_of_cycle'`

   if [[ -n "$CCL" ]]; then
      # Update the out-of-cycle child channel
      echo ""
      echo "Updating cloned children for $TARGET"
   fi

   # Look at each identified child channel to see if there is a match in the "CCPS" map
   for CC in $CCL; do
      CCS=`echo $CCPS | sed 's/ /\n/g' | grep ":${CC}$" | awk -F':' '{print $1}'`
      if [[ -n $CCS ]]; then
         echo "   Updating $CC from $CCS"
         #echo "$CLONE_BY_DATE -y -g -l $CCS $CC -a $SOURCE $TARGET --username $SATELLITE_LOGIN --password $SATELLITE_PASSWORD --to_date=${END_DATE}"
         $CLONE_BY_DATE -z -y -g -l $CCS $CC -a $SOURCE $TARGET --username $SATELLITE_LOGIN --password $SATELLITE_PASSWORD --to_date=${END_DATE}
      else
         echo "   No source listed for $CC, skipping."
      fi
   
   done

   # Update the out-of-cycle child channel
   echo ""
   echo "Updating out_of_cycle for $TARGET"

   # Programatically find the OOC channel name
   OOC=`$API_SCRIPT channel.listSoftwareChannels "%session%" | sed "s/^[ \t]*//g" | sed ':a;N;$!ba;s/\n//g;s/{/\n/g;' | grep "'parent_label' => '${TARGET}'," | awk -F"'label' => '" '{print $2}' | awk -F"'" '{print $1}' | grep 'out_of_cycle'`
   echo "   Identified [$OOC]"
   # Create a list of packages in the OOC by name (we will ignore multiples)
   OOCPACKAGES=`$API_SCRIPT channel.software.listAllPackages "%session%" $OOC | egrep "{|}|'arch_label' =>|'name' =>" | sed ':a;N;$!ba;s/\n//g;s/{/\n/g;' | awk -F"'" '{print $8"."$4}' | sort -u`

   # Assuming there are any packages in the OOC channel...
   if [[ -n $OOCPACKAGES ]]; then

      # Make a list of package IDs for the latest versions of the packages currently in OOC
      ADDLIST=
      for OOCPACKAGE in $OOCPACKAGES; do
         #echo "Checking for $OOCPACKAGE in $LATEST"
         if [[ -n `grep "^${OOCPACKAGE}," $LATEST` ]]; then
            ADDLIST="${ADDLIST},`grep "^${OOCPACKAGE}," $LATEST | awk -F',' '{print $2}'`"
         fi
      done
   
      # Trim the result
      BUFF=$ADDLIST
      ADDLIST=`echo $BUFF | sed 's/^,//g;s/,$//g'`
   
      # If we need to add packages, go ahead and try it
      if [[ -n $ADDLIST ]]; then
         RESULT_STRING=`$API_SCRIPT channel.software.addPackages "%session%" "$OOC" "[${ADDLIST}]"`
         if [[ -n `echo $RESULT_STRING | grep "result = '1'"` ]]; then
               echo "   Packages added successfully"
         else
            echo "   Error adding packages"
         fi
      else
         echo "No updates needed for $OOC"
      fi
   else
      echo "No packages found in $OOC"
   fi

   
done
/bin/logger -t satellite ": job start [$0]"
exit

