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
temp=$(cat /etc/*-release | grep -m 1 release)
OSVersion=${temp//[^0-9.]}
}

CheckInstallJava () {
if type -p java &> /dev/null
then
   return 0
else
   return 1
fi   
}

GetVersionJava () {
JavaVer=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
}

CheckInstallTomcat () {
#temp=$(ps -ef | grep -m 1 tomcat | awk '{print $1}')
#echo $temp
#echo $USER
if [[ "$(ps -ef | grep -m 1 tomcat | awk '{print $1}')" != "$USER" ]]
   then 
      return 0
fi
if [ "$OSName" = "Ubuntu" ]
   then
      if [ -z "$(dpkg -l | grep tomcat)" ]
         then
            return 1 
         else
            return 0   
      fi
fi
if [ -z "$(yum list installed | grep tomcat)" ]
   then
      return 1
   else
      return 0
fi
}

#CheckVersionTomcat () {
#
#}

IsRoot () {
if [ "$(id -u)" = "0" ]; 
   then
      return 0
   else
      return 1
fi
}

if GetOSName
   then
      :
   else
      echo "Ошибка. Неподдерживаемый тип ОС."
      exit 1     
fi

GetOSVersion
case $OSName in
   Ubuntu)
      if [[ "$OSVersion" < "14" ]]
         then
            echo "Неподдерживамая версия Ubuntu"
            exit 1
      fi
   ;;
   CentOS)
      if [[ "$OSVersion" < "6" ]]
         then
            echo "Неподдерживамая версия CentOS"
            exit 1
      fi
   ;;
   RHEL)
      if [[ "$OSVersion" < "6" ]]
         then
            echo "Неподдерживамая версия RHEL"
            exit 1
      fi
   ;;
esac

if CheckInstallJava
   then      
      GetVersionJava
      if [[ "$JavaVer" < "1.8" ]]
         then
            echo "Необходимо установить Java выше 1.8"
            exit 1
      fi   
   else
      NeedJava=true
fi

if CheckInstallTomcat
   then
      echo "Tomcat installed"
   else
      echo "Tomcat not installed"
fi
#CheckVersionTomcat

#if IsRoot
#   then
#   :
#else
#   echo "Все проверки пройдены, но для установки скрипт должен быть запущен от root"
#   exit 1
#fi

