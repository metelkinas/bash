#!/bin/bash
GetOSName () {
if [ -n "$(cat /etc/*-release | grep Ubuntu)" ]
   then
      OSName="Ubuntu"
      return 0	
fi
if [ -n "$(cat /etc/*-release | grep CentOS)" ]
   then
      OSName="CentOS"
      return 0		
fi	
if [ -n "$(cat /etc/*-release | grep "Red Hat Enterprise")" ]
   then
      OSName="Red Hat Enterprise"
      return 0		
fi
OSName="XZ"
return 1
}

GetOSVersion () {
#if [ "$OSName" = "CentOS" ]
#   then
#      OSVersion=$((cat /etc/*-release | grep VERSION_ID) | sed -e 's/.*"\(.*\)".*/\1/')
#      return 0
#   else
#      OSVersion=$(lsb_release -rs)
#      return 0
#fi
OSVersion=$(lsb_release -rs)
echo $?
if [ $? -ne 0 ]
   then
      OSVersion=$((cat /etc/*-release | grep VERSION_ID) | sed -e 's/.*"\(.*\)".*/\1/')
      return 0
fi	
return 0
}

GetOSName
echo $OSName
GetOSVersion
echo $OSVersion
