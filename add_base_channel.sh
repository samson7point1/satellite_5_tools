#!/bin/bash

FQRN=$1
ANSWER=NO
source /var/satellite/maintenance/scrits/.satenv



#Verify 1 argument is provided with the script
NUMARGS=$#
if [ $NUMARGS -ne 1 ]; then
	echo "###############################################"
        echo "Usage: /var/satellite/maintenance/add_base_channel.sh rh#_u##x##"
        echo "EXAMPLE: /var/satellite/maintenance/add_base_channel.sh rh5_u9x32"
	echo "###############################################"
        exit
fi

#Verifying the naming standard
VFQRN="`echo $FQRN | egrep "rh[0-9]{1}_u[0-9]{1,2}x[32,64]{1}"`"

if [[ -z $VFQRN ]]; then
	echo The fully qualified name - $FQRN - does not meet standards.  Make sure it follows the standard "rh#_u#x##"
	exit
else
	echo name is correct $VFQRN
fi

#One last final manual verification that all appears to be good
while [[ $ANSWER == NO ]]; do
	read -p "Are you sure you want to create base channel $VFQRN [y/n]" ACHECK
	if [[ $ACHECK == y ]]; then
		ANSWER=YES
	else
		echo "Please re-run the script with the correct name you need"
		exit
	fi
done

#Now time to do the work and set all the variables
RELEASE=`echo $FQRN | awk -F_ '{print $1}' | sed 's/rh//'`
UPDATE=`echo $FQRN | awk -F_ '{print $2}' | awk -Fx '{print $1}' | sed 's/u//'`
ARCHITECTURE=`echo $FQRN | awk -Fx '{print $2}' | sed 's/x//;s/64/x86_64/g;s/32/i386/g'`

echo "Please provide the password for $USER"
spacewalk-create-channel -s $HOSTNAME -v $RELEASE -r Server -u u$UPDATE -a $ARCHITECTURE -d $FQRN --user $USER
