#/bin/bash

if [[ -n `/usr/bin/spacewalk-report inventory | grep -v ^server_id | awk -F',' '($10 != 0) {print $3","$4","$10}'` ]]; then
   echo "The following systems are registered with Red Hat Satellite and are out of date"
   echo ""
   echo "System Profile                           IP Address           Number of Packages Out-of-Date"
   echo "---------------------------------------------------------------------------------------------"
   /usr/bin/spacewalk-report inventory | grep -v ^server_id | awk -F',' '($10 != 0) {printf "%-40s %-20s %s\n", $3, $4, $10}'
fi

