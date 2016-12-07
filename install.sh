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
      OSName="RHEL"
      return 0		
fi
return 1
}

GetOSVersion () {
if [ "$OSName" = "Ubuntu" ]
   then
      OSVersion=$(lsb_release -rs)
      return 0	
fi
if [ "$OSName" = "RHEL" ]
   then
      OSVersion=$(cat /etc/*-release | grep -m 1 release | awk '{ print $7 }')
      return 0
fi
#cat /etc/*-release | grep -m 1 release
}

GetOSName
echo $OSName
GetOSVersion
echo $OSVersion
