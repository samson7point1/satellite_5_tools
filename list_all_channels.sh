#!/bin/bash

# list all software channels on the satellite server

# Define base API script string

source /var/satellite/maintenance/scrits/.satenv

API_SCRIPT="/var/satellite/maintenance/scripts/spacewalk-api-custom --server=$SATELLITE_SERVER --user=$SATELLITE_LOGIN --password=$SATELLITE_PASSWORD"

# If this script is used with "-i" produce an indented list of channels
if [[ -n $1 ]] && [[ $1 == -i ]]; then

   # Dump a list of all channels into a variable
   ALL_CHANNELS_LIST=`$API_SCRIPT channel.listSoftwareChannels "%session%" | grep "'label' =>" | awk -F"'" '{print $4}'`

   # Create a temp file to hold the channel metadata
   CHMETA_TMP=.`basename $0`_$$.tmp

   # Populate the temp file to hold the channel metadata
   $API_SCRIPT channel.listSoftwareChannels "%session%" | sed "s/^[ \t]*//g" | sed ':a;N;$!ba;s/\n//g;s/{/\n/g;' > $CHMETA_TMP

   # Look at each channel on the server
   for CHANNEL in $ALL_CHANNELS_LIST; do

      # Grab the channel metadata from the temp file
      CHLINE=`grep "'label' => '${CHANNEL}'" $CHMETA_TMP`

      # If the channel has no parent label listed then it is a parent
      if [[ -n `echo $CHLINE | grep "'parent_label' => '',"` ]]; then

         # Print the name of the parent channel
         echo $CHANNEL

         # Print this parent's child channels, and add a 3 space indent
         grep "'parent_label' => '${CHANNEL}'," $CHMETA_TMP | awk -F"'label' => '" '{print $2}' | awk -F"'" '{print $1}' | sed 's/^/   /g'
  
         # Print a blank line to separate the output
         echo ""
      fi

   done

   # Clean up the temp file
   if [[ -f $CHMETA_TMP ]]; then /bin/rm $CHMETA_TMP; fi

else

   # If run without recognized arguments just output a flat list of channels on the server

   $API_SCRIPT channel.listSoftwareChannels "%session%" | grep "'label' =>" | awk -F"'" '{print $4}'

fi
exit

