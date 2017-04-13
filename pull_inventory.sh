#!/bin/bash

#################FUNCTION DEFINITIONS########################

#-----------------
# Function: f_PathOfScript
#-----------------
# Returns the location of the script, irrespective of where it
# was launched.  This is useful for scripts that look for files
# in their current directory, or in relative paths from it
#
#-----------------
# Usage: f_PathOfScript
#-----------------
# Returns: <PATH>

f_PathOfScript () {

   unset RESULT

   # if $0 begins with a / then it is an absolute path
   # which we can get by removing the scipt name from the end of $0
   if [[ -n `echo $0 | grep "^/"` ]]; then
      BASENAME=`basename $0`
      RESULT=`echo $0 | sed 's/'"$BASENAME"'$//g'`

   # if this isn't an absolute path, see if removing the ./ from the
   # beginning of $0 results in just the basename - if so
   # the script is being executed from the present working directory
   elif [[ `echo $0 | sed 's/^.\///g'` == `basename $0` ]]; then
      RESULT=`pwd`

   # If we're not dealing with an absolute path, we're dealing with
   # a relative path, which we can get with pwd + $0 - basename
   else
      BASENAME=`basename $0`
      RESULT="`pwd`/`echo $0 | sed 's/'"$BASENAME"'$//g'`"
   fi

   echo $RESULT

}

cd `f_PathOfScript`

# Include common_functions.h
if [[ -s /opt/sa/scripts/common_functions.sh ]]; then
   source /opt/sa/scripts/common_functions.sh
elif [[ -s common_functions.sh ]]; then
   source common_functions.sh
else
   echo "Critical dependency failure: unable to locate common_functions.h"
   exit 1
fi

#### SETTINGS ####

# If VERBOSE is 0, output is suppressed, if it is non-zero output is displayed
VERBOSE=0

# Login account
LOGIN=unixpa
PKEY=unixpa.key

# Commands and arguments
SSH="/usr/bin/ssh -q -i $PKEY -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Generate a list of managed systems
# Format: <hostname>,<IP>
MSYSTEM_LIST=`/usr/bin/spacewalk-report inventory | awk -F',' '{print $2","$4}'`

# Override for testing
#MSYSTEM_LIST="kneoraolt002,10.252.12.184
#kneoraolt001,10.252.12.164"

# Begin main loop

# echo "$OS_HOSTNAME,$HW_CPU_CORES,$HW_CPU_THREADS,$HW_CPU_SOCKETS,$HW_CPU_VEND,$HW_CPU_NAME,$HW_CPU_SPEED,$NET_PUBIP,,$HW_MANU,$HW_PRODUCT,$OS_NAME $OS_RELEASE,Update $OS_UPDATE,$OS_VERSION,$HW_MEM_MB" 

for MSYSTEM in $MSYSTEM_LIST; do

   OS_HOSTNAME=`echo $MSYSTEM | awk -F',' '{print $1}'`
   NET_PUBIP=`echo $MSYSTEM | awk -F',' '{print $2}'`

   # Verify connectivity
   $SSH ${LOGIN}@${NET_PUBIP} "/bin/true" &> /dev/null
   RETVAL=$?

   if [[ $RETVAL == 0 ]]; then

      ## CPU Details
      CPUINFO=/tmp/.rsci
      if [[ -f $CPUINFO ]]; then /bin/rm $CPUINFO; fi
      $SSH ${LOGIN}@${NET_PUBIP} "cat /proc/cpuinfo" > $CPUINFO

      # Get a physical core count by looking at how many unique core ids we have per physical id
      unset HW_CPU_CORES
      for i in `cat $CPUINFO | grep "physical id" | sort -u | awk '{print $NF}'`; do
         THIS_CORE_COUNT=`cat $CPUINFO | sed 's/\t/ /g' | sed 's/ //g' | awk /"physicalid:$i"/,/"coreid"/ | grep "coreid"| sort -u | wc -l`
         let HW_CPU_CORES=$HW_CPU_CORES+$THIS_CORE_COUNT
      done

      # If the above comes back empty we're most likely dealing with a single-core system
      if [[ -z $HW_CPU_CORES ]]; then
         HW_CPU_CORES=1
      fi

      # Get a thread count based on the raw number of "processors" showing up
      HW_CPU_THREADS=`cat $CPUINFO | grep "^processor" | wc -l`

      # Get a socket count by looking at how many unique physical ids there are
      HW_CPU_SOCKETS=`cat $CPUINFO | grep "physical id" | sort -u | wc -l`
      if [[ -z $HW_CPU_SOCKETS ]] || [[ $HW_CPU_SOCKETS == 0 ]]; then
         HW_CPU_SOCKETS=1
      fi

      HW_CPU_VEND=$( cat $CPUINFO | grep -m1 "^vendor_id" | awk -F':' '{print $2}' | sed 's/^ //g;s/  */ /g' )
      HW_CPU_NAME=$( cat $CPUINFO | grep -m1 "^model name" | awk -F':' '{print $2}' | sed 's/^ //g;s/  */ /g' )
      HW_CPU_SPEED=$( cat $CPUINFO | grep -m1 "^cpu MHz" | awk -F':' '{print $2}' | sed 's/^ //g;s/  */ /g' | awk -F'.' '{print $1}')

      if [[ -f $CPUINFO ]]; then /bin/rm $CPUINFO; fi


      ## Chipset info 
      DMID=/tmp/.rsdd
      if [[ -f $DMID ]]; then /bin/rm $DMID; fi
      $SSH ${LOGIN}@${NET_PUBIP} "/usr/bin/sudo /usr/sbin/dmidecode" > $DMID
      HW_MANU=`cat $DMID | awk /"System Information"/,/"Serial Number"/ | grep Manufacturer: | awk -F': ' '{print $2}' | tr -d ','`
      HW_PRODUCT=`cat $DMID | awk /"System Information"/,/"Serial Number"/ | grep "Product" | sed 's/.*Product Name:[ \t]//'`
      HW_SERIAL=`cat $DMID | awk /"System Information"/,/"Serial Number"/ | grep "Serial Number" | awk -F': ' '{print $NF}'`
      HW_MEM_MB=`cat $DMID | egrep "^[[:space:]]Size:" | egrep -v "No" | awk '{sum+=$2} END {print sum}'`
      
      if [[ -f $DMID ]]; then /bin/rm $DMID; fi
   

      # OS Software Details
      OS_RELEASE_FULL=`$SSH ${LOGIN}@${NET_PUBIP} "cat /etc/redhat-release"`
      OS_NAME=`echo $OS_RELEASE_FULL | awk -F'release' '{print $1}' | sed 's/ $//g'`
      OS_RELEASE=`echo $OS_RELEASE_FULL | awk -F'release ' '{print $2}' | awk -F'.' '{print $1}'`
      OS_UPDATE=`echo $OS_RELEASE_FULL | awk -F'release ' '{print $2}' | awk '{print $1}' | awk -F'.' '{print $2}'`
      OS_VERSION=`$SSH ${LOGIN}@${NET_PUBIP} "/bin/rpm -qa --qf '%{RELEASE}' redhat-release-server" | awk -F'.el' '{print $1}'`
      if [[ -z $OS_VERSION ]]; then
         OS_VERSION=`$SSH ${LOGIN}@${NET_PUBIP} "/bin/rpm -qa --qf '%{RELEASE}' redhat-release"`
      fi

      MISC_LOCATION=`/usr/bin/spacewalk-report custom-info | grep ",$OS_HOSTNAME," | grep ",Location," | awk -F',' '{print $5}' | tr -d '"'`
      MISC_APPLICATION=`/usr/bin/spacewalk-report custom-info | grep ",$OS_HOSTNAME," | grep ",Application," | awk -F',' '{print $5}' | tr -d '"'`
   
      echo "$OS_HOSTNAME,$HW_CPU_CORES,$HW_CPU_THREADS,$HW_CPU_SOCKETS,$HW_CPU_VEND,$HW_CPU_NAME,$HW_CPU_SPEED,$NET_PUBIP,$MISC_LOCATION,$HW_MANU,$HW_PRODUCT,$OS_NAME $OS_RELEASE,Update $OS_UPDATE,,$OS_VERSION,$HW_MEM_MB,$HW_SERIAL,$MISC_APPLICATION" 

   fi

done

exit



