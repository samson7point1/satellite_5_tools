#!/bin/bash

/bin/logger -t satellite ": job start [$0]"


source /var/satellite/maintenance/scrits/.satenv

SCRIPT_DIR="/var/satellite/maintenance/scripts"
API_SCRIPT="${SCRIPT_DIR}/spacewalk-api-custom --server=$SATELLITE_SERVER --user=$SATELLITE_LOGIN --password=$SATELLITE_PASSWORD"
CLONE_BY_DATE="/usr/bin/spacewalk-clone-by-date"
BLACKLIST="${SCRIPT_DIR}/blacklist.txt"
KNOWN_SEV="${SCRIPT_DIR}/.known_severity"
LFSC="${SCRIPT_DIR}/.latest_name_and_id_${source_channel}_$$.txt"
KNOWN_REQ="${SCRIPT_DIR}/.known_requires"
TERM=xterm
export TERM

cd $SCRIPT_DIR

# Build update channels list
UPDATE_CHANNEL_LIST=`$API_SCRIPT channel.listSoftwareChannels "%session%" | grep "'label' =>" | awk -F"'" '{print $4}' | grep "_updates$"`

for UPDATE_CHANNEL in $UPDATE_CHANNEL_LIST; do
   
   echo "Updating $UPDATE_CHANNEL..."
   # Determine the appropriate source channel to update from
   if [[ -n `echo $UPDATE_CHANNEL | egrep 'rh5|rhel5'` ]] && [[ -n `echo $UPDATE_CHANNEL | egrep 'x64|x86_64'` ]]; then
      SOURCE=rhel-x86_64-server-5
   elif [[ -n `echo $UPDATE_CHANNEL | egrep 'rh7|rhel7'` ]] && [[ -n `echo $UPDATE_CHANNEL | egrep 'x64|x86_64'` ]]; then
      SOURCE=rhel-x86_64-server-7
   elif [[ -n `echo $UPDATE_CHANNEL | egrep 'rh6|rhel6'` ]] && [[ -n `echo $UPDATE_CHANNEL | egrep 'x64|x86_64'` ]]; then
      SOURCE=rhel-x86_64-server-6
   elif [[ -n `echo $UPDATE_CHANNEL | egrep 'rh5|rhel5'` ]] && [[ -n `echo $UPDATE_CHANNEL | egrep 'x32|32bit'` ]]; then
      SOURCE=rhel-i386-server-5
   else
      echo "   Error: unable to determine correct source channel for updating $UPDATE_CHANNEL"
      exit
   fi

   echo "   elected $SOURCE as the source channel."

   # Create a file to hold the latest name-to-id mapping for the Source channel
   LATEST=${SCRIPT_DIR}/.latest.$SOURCE

   # Builld a "LATEST" list
   echo "   building channel to ID list for $SOURCE"
   $API_SCRIPT channel.software.listLatestPackages "%session%" "$SOURCE" | egrep "{|}|'name' =>|'id' =>|'arch_label' =>" | tr -d "'," | sed ':a;N;$!ba;s/\n//g;s/{/\n/g;' | egrep -v "^[ \t]*$" | awk '{print $6"."$3","$9}' > $LATEST

   # Create a list of packages in the update channel by name
   PACKAGE_LIST=`$API_SCRIPT channel.software.listAllPackages "%session%" $UPDATE_CHANNEL | egrep "{|}|'arch_label' =>|'name' =>" | sed ':a;N;$!ba;s/\n//g;s/{/\n/g;' | grep -v '^[[:space:]]*$' | awk -F"'" '{print $8"."$4}' | sort -u`

   # Assuming there are any packages in the OOC channel...
   if [[ -n $PACKAGE_LIST ]]; then

      # Make a list of package IDs for the latest versions of the packages currently in OOC
      ADDLIST=
      for PACKAGE in $PACKAGE_LIST; do
         PACKAGE_NOARCH=`echo $PACKAGE | awk -F'.' '{print $1}'`
         #echo "Checking for $OOCPACKAGE in $LATEST"
         #if [[ -n `grep "^${PACKAGE}," $LATEST` ]]; then
         if [[ -n `egrep -i "^${PACKAGE_NOARCH}$|^${PACKAGE_NOARCH}[[:space:]]$" $BLACKLIST` ]]; then
            echo "      Automatic update of $PACKAGE blocked by blacklist"
         else
            echo "      Checking for updated versions of $PACKAGE"
            if [[ -n `grep "^${PACKAGE}," $LATEST` ]]; then
               ADDLIST="${ADDLIST},`grep "^${PACKAGE}," $LATEST | awk -F',' '{print $2}'`"
            fi
         fi
      done
   
      # Trim the result
      BUFF=$ADDLIST
      ADDLIST=`echo $BUFF | sed 's/^,//g;s/,$//g'`
   
      # If we need to add packages, go ahead and try it
      if [[ -n $ADDLIST ]]; then
         echo "   Attempting to add new packages to $UPDATE_CHANNEL"
         RESULT_STRING=`$API_SCRIPT channel.software.addPackages "%session%" "$UPDATE_CHANNEL" "[${ADDLIST}]"`
         if [[ -n `echo $RESULT_STRING | grep "result = '1'"` ]]; then
               echo "   Packages added successfully"
         else
            echo "   Error adding packages"
         fi
      else
         echo "No updates needed for $UPDATE_CHANNEL"
      fi
   else
      echo "No packages found in $UPDATE_CHANNEL"
   fi

   
done
/bin/logger -t satellite ": job end [$0]"
exit

