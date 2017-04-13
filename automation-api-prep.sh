################# API Call Pre-Execution Prep ################
# Set variables
API_URL=https://kneschiwp001.kiewitplaza.com/reportingapi/
API_USER=automation.reporting
API_PASS=5ee5omethIng5ay5omethIng
ORIGIN=`hostname`
TARGET=$ORIGIN
PNAME=`basename $0`
TB=$USER
#CAT=prevention
#DESC="Oracle Log Cleanup"
TARGETIP=`getent hosts $TARGET | awk '{print $1}'`
#TIMESAVED=15
START=`date "+%Y-%m-%d %H:%M:%S"`

############### End API Call Pre-Execution Prep ################

