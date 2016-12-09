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
TomcatProc=false
TomcatPak=false
if [ "$OSName" = "Ubuntu" ]
   then
      if [ -z "$(dpkg -l | grep tomcat)" ]
         then
            return 1 
         else
            TomcatPak=true
            return 0   
      fi
fi
if [ -z "$(yum list installed | grep tomcat)" ]
   then
      return 1
   else
      TomcatPak=true
      return 0
fi
if [[ "$(ps -ef | grep -m 1 catalina | awk '{print $1}')" != "$USER" ]]
   then
      TomcatProc=true 
      return 0
fi
}

GetVersionTomcat () {
TomcatVersion=0
if $TomcatPak
   then
      temp=$(ls /usr/share/ | grep -m 1 tomcat)
      TomcatVersion=${temp//[^0-9]}
      return 0 
   else
      temp=$(ps -ef | grep -m 1 catalina.home)
      for i in $temp; do 
         if [[ "$i" =~ "-Dcatalina.home=" ]]
         then
            PathToCatalina=$(echo $i | awk -F"=" '{ print $2 }')
            break
         fi
      done
      cmd="$PathToCatalina/bin/catalina.sh version"
      temp=$(exec $cmd | grep "Server number")
      TomcatVersion=${temp//[^0-9.]}
      return 0
fi
}

JavaInstall () {
if type -p wget &> /dev/null
then
   :
else
case $OSName in
   Ubuntu)
      apt-get update 
      apt-get install -y wget
   ;;
   CentOS|RHEL)
      yum update
      yum install -y wget
   ;;
esac   
fi   
wget http://download.java.net/java/jdk8u122/archive/b04/binaries/jdk-8u122-ea-bin-b04-linux-x64-25_oct_2016.tar.gz
# добавить проверку существования директории
mkdir /opt/java
tar -xzf jdk-8u122-ea-bin-b04-linux-x64-25_oct_2016.tar.gz --strip-components=1 -C /opt/java
rm -f jdk-8u122-ea-bin-b04-linux-x64-25_oct_2016.tar.gz
echo "## Setting JAVA_HOME and PATH for all USERS ##" >> /etc/profile
echo "export JAVA_HOME=/opt/java/jre" >> /etc/profile
echo "export PATH=\$PATH:\$JAVA_HOME/bin" >> /etc/profile
source /etc/profile
}

TomcatInstall () {
if type -p wget &> /dev/null
then
   :
else
case $OSName in
   Ubuntu)
      apt-get update 
      apt-get install -y wget
   ;;
   CentOS|RHEL)
      yum update
      yum install -y wget
   ;;
esac   
fi   
wget http://apache-mirror.rbc.ru/pub/apache/tomcat/tomcat-8/v8.5.8/bin/apache-tomcat-8.5.8.tar.gz
# добавить проверку существования директории
mkdir /opt/tomcat
tar -xzf apache-tomcat-8.5.8.tar.gz --strip-components=1 -C /opt/tomcat
rm -f apache-tomcat-8.5.8.tar.gz
echo "## Setting Tomcat and PATH for all USERS ##" >> /etc/profile
echo "export CATALINA_HOME=/opt/tomcat" >> /etc/profile
echo "export PATH=\$PATH:\$CATALINA_HOME/bin" >> /etc/profile
echo "export PATH=\$PATH:\$CATALINA_HOME/scripts" >> /etc/profile
source /etc/profile
}

#TomcatCinfigure () {
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

if IsRoot
   then
   :
else
   echo "Все проверки пройдены, но для установки скрипт должен быть запущен от root"
   exit 1
fi

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

NeedJava=false
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

NeedTomcat=false
if CheckInstallTomcat
   then
      GetVersionTomcat
      if [[ "$TomcatVersion" < "8" ]]
         then
            echo "Необходимо установить Tomcat 8"
            exit 1
      fi 
   else
      NeedTomcat=true
fi

NeedJava=false
NeedTomcat=true

if [ "$NeedJava" = "true" ] && [ "$NeedTomcat" = "true" ]
   then
      echo -n "Tomcat + Java. Продолжить? (y/n) "
      read item
      case "$item" in
         y|Y) 
            JavaInstall
            TomcatInstall   
            NeedJava=false
            NeedTomcat=false                       
         ;;
         n|N) 
            echo "Ввели «n», завершаем..."
            exit 0
        ;;
         *) 
            echo "Ничего не ввели. Выполняем действие по умолчанию... выходим"
        ;;
      esac
fi
if [ "$NeedJava" = "true" ]
   then
      echo -n "Java. Продолжить? (y/n) "
      read item
      case "$item" in
         y|Y) 
            JavaInstall
            NeedJava=false
         ;;
         n|N) 
            echo "Ввели «n», завершаем..."
            exit 0
         ;;
         *) 
            echo "Ничего не ввели. Выполняем действие по умолчанию... выходим"
         ;;
      esac
fi         
if [ "$NeedTomcat" = "true" ]
   then
      echo -n "Tomcat. Продолжить? (y/n) "
      read item
      case "$item" in
         y|Y) 
            TomcatInstall  
            NeedTomcat=false
         ;;
         n|N) 
            echo "Ввели «n», завершаем..."
            exit 0
         ;;
         *) 
            echo "Ничего не ввели. Выполняем действие по умолчанию... выходим"
         ;;
      esac                    
                       
fi
echo "install NGB"
exit 0