#!/bin/bash
TEMPFILE=/tmp/cstatus.tmp
HEADFILE=/tmp/cstatushead.tmp
BODYFILE=/tmp/cstatusbody.tmp
DEBUG=$1

RED='\033[0;31m'
YEL='\033[1;33m'
CYA='\033[0;36m'
GRE='\033[0;32m'
NC='\033[0m'
TAB='\t'

if [[ "$DEBUG" == "DEBUG" ]]
then
    echo running with tmp files already created
else
    splunk show cluster-status > $TEMPFILE
fi

sed -ne '/Replication/,/^$/ p' < $TEMPFILE | paste - - - - - | egrep -o "[A-Z].*" > $HEADFILE
sed -ne "/$TAB.*$TAB/,$ p" < $TEMPFILE | egrep -v '^$' | paste - - - - | sort > $BODYFILE
sed -ne '/Peers restarting/,/^$/ p' < $TEMPFILE > /tmp/cstatus.restarting.tmp
sed -ne '/Peers to be rest/,/^$/ p' < $TEMPFILE > /tmp/cstatus.toberestarted.tmp
sed -ne '/Peers restarted/,/^$/ p' < $TEMPFILE > /tmp/cstatus.restarted.tmp

# if things are not good, color the first line of output RED or YELLOW
if egrep -q "(not searchable)|(Ready.*NO)" $HEADFILE
then
    COLOR=$RED
elif egrep -q "(not met)|(in progress)" $HEADFILE
then
    COLOR="$YEL"
else
    COLOR="$GRE"
fi
# print the line with color combo, then reset to no color
echo -ne $COLOR
cat $HEADFILE | sed -e 's/Replication factor /RF=/' | \
                sed -e 's/Search factor /SF=/' | \
                sed -e 's/All data is //' | \
                sed -e 's/Ready /Ready:/' 
echo -ne $NC

# for each peer, parse the line and dump it with color decor if needed
while read -a LINE
do
    PEER="${LINE[0]}"
    GUID="${LINE[1]}"
    SEARCHABLE="${LINE[4]}"
    STATUS="${LINE[6]}"
    BUCKET="${LINE[8]}"

    if ! echo $STATUS | egrep -q "Up"
    then 
        STATUS_COLOR="$YEL"
    else
        STATUS_COLOR="$GRE"
    fi

    if ! echo $SEARCHABLE | egrep -q "YES"
    then 
        SRCH_COLOR="$YEL"
    else
        SRCH_COLOR="$GRE"
    fi

    echo -ne "${PEER}${TAB}Status:${STATUS_COLOR}${STATUS}${NC}${TAB}Searchable:${SRCH_COLOR}${SEARCHABLE}${NC}${TAB}${GUID}${TAB}${BUCKET}\n"
done < $BODYFILE

echo
if grep -q Peers /tmp/cstatus.toberestarted.tmp
then
    echo "Servers need to restart:     $(wc -l /tmp/cstatus.toberestarted.tmp)"
fi

if grep -q Peers /tmp/cstatus.restarting.tmp
then
    echo "Server currently restarting: $(awk '{print $3}' < /tmp/cstatus.restarting.tmp)"
fi
