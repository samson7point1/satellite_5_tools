#!/bin/bash

# Deletes all archived actions, archives all remaining

/bin/logger -t satellite ": job start [$0]"

SCRIPT_DIR="/var/satellite/maintenance/scripts"

cd $SCRIPT_DIR

# Delete all archived actions
./arsa2.py -c -a authfile | egrep -v "Found |Archiving actions|Enabling workaround|^\["
./arsa2.py -c -a authfile | egrep -v "Found |Archiving actions|Enabling workaround|^\["

# Archive all remaining actions
./arsa2.py -f -a authfile | egrep -v "Found |Archiving actions|Enabling workaround|^\["
./arsa2.py -f -a authfile | egrep -v "Found |Archiving actions|Enabling workaround|^\["

/bin/logger -t satellite ": job end [$0]"
exit

