#!/bin/bash

#Function is designed to clean up files in case of interruption or standard completion of the script
function _CLEANUP {
        exit
}

#This will catch any abnormal termination of the script and call the _CLEANUP function to make sure files are cleaned up
trap _CLEANUP SIGHUP SIGINT SIGTERM

#Define paths to commands
PRINTF="/usr/bin/printf"
SAT_REPORT="/usr/bin/spacewalk-report"
AWK="/bin/awk"
MAIL="/bin/mail"
SORT="/bin/sort"
UNIQ="/usr/bin/uniq"

#Make the satellite scripts path a variable
WPATH="/var/satellite/maintenance/scripts"

#Define recipients of the report
RECIPIENTS="serveradmincore@kiewit.com"

#Pull in the system list but only grabbing server_id and server_name.  This will be used to translate server ID later
DUPLICATES=`$SAT_REPORT inventory | $AWK -F ',' '{ print $2 }' | $SORT | $UNIQ -d`

#Email the report to the recipients in the variable defined in the beginning
$PRINTF "Please clean up the following duplicate servers in RHSS\n$DUPLICATES" | $MAIL -s 'Duplicate Entries in Satellite Server' $RECIPIENTS

#Cleanup all leftover files for a clean run next month
_CLEANUP
