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

groupadd tomcat
useradd -M -d /opt/tomcat/ -g tomcat -s /sbin/nologin tomcat
cd /opt/tomcat
chgrp -R tomcat conf
chmod g+rwx conf
chmod g+r conf/*
chown -R tomcat webapps/ work/ temp/ logs/
cd /opt/tomcat
chgrp -R tomcat conf
chmod g+r conf/*
echo JAVA_OPTS="-Xms256m -Xmx2048m -XX:MaxPermSize=768m -XX:ReservedCodeCacheSize=225m -XX:MaxDirectMemorySize=2048m" > /opt/tomcat/bin/setenv.sh

if [ "$OSName" = "Ubuntu" ] && [ "$OSVersion" -ge "14" ] || [ "$OSName" = "CentOS" ] && [ "$OSVersion" -ge "7" ] || [ "$OSName" = "RHEL" ] && [ "$OSVersion" -ge "7" ]
   then    
      echo "# Systemd unit file for tomcat" > /etc/systemd/system/tomcat.service
      echo "[Unit]" >> /etc/systemd/system/tomcat.service
      echo "Description=Apache Tomcat Web Application Container" >> /etc/systemd/system/tomcat.service
      echo "After=syslog.target network.target" >> /etc/systemd/system/tomcat.service
      echo "[Service]" >> /etc/systemd/system/tomcat.service
      echo "Type=forking" >> /etc/systemd/system/tomcat.service
      echo "Environment=JAVA_HOME=/opt/java/jre" >> /etc/systemd/system/tomcat.service
      echo "Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid" >> /etc/systemd/system/tomcat.service
      echo "Environment=CATALINA_HOME=/opt/tomcat" >> /etc/systemd/system/tomcat.service
      echo "Environment=CATALINA_BASE=/opt/tomcat" >> /etc/systemd/system/tomcat.service
      echo "Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'" >> /etc/systemd/system/tomcat.service
      echo "Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandom'" >> /etc/systemd/system/tomcat.service
      echo "ExecStart=/opt/tomcat/bin/startup.sh" >> /etc/systemd/system/tomcat.service
      echo "ExecStop=/bin/kill -15 $MAINPID" >> /etc/systemd/system/tomcat.service
      echo "User=tomcat" >> /etc/systemd/system/tomcat.service
      echo "Group=tomcat" >> /etc/systemd/system/tomcat.service
      echo "[Install]" >> /etc/systemd/system/tomcat.service
      echo "WantedBy=multi-user.target" >> /etc/systemd/system/tomcat.service
      systemctl daemon-reload
      systemctl enable tomcat   
   else
      echo "systemd"
fi
}

NGBInstall () { 
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
echo "CATGENOME_CONF_DIR=/opt/tomcat/conf/catgenome/" >> /opt/tomcat/conf/catalina.poperties

mkdir /opt/tomcat/conf/catgenome/
echo "files.base.directory.path=/opt/catgenome/contents" > /opt/tomcat/conf/catgenome/catgenome.properties
echo "database.max.pool.size=25" >> /opt/tomcat/conf/catgenome/catgenome.properties
echo "database.username=catgenome" >> /opt/tomcat/conf/catgenome/catgenome.properties
echo "database.password=" >> /opt/tomcat/conf/catgenome/catgenome.properties
echo "database.initial.pool.size=5" >> /opt/tomcat/conf/catgenome/catgenome.properties
echo "database.driver.class=org.h2.Driver" >> /opt/tomcat/conf/catgenome/catgenome.properties
echo "database.jdbc.url=jdbc:h2:file:/opt/catgenome/H2/catgenome" >> /opt/tomcat/conf/catgenome/catgenome.properties

cd /opt
mkdir catgenome
chown tomcat:tomcat catgenome
chgrp -R tomcat catgenome
chmod g+w catgenome

cd /opt/tomcat/webapps/
wget http://52.38.214.1/distr/latest/catgenome.war

mkdir /opt/catgenome/ngb-cli
cd /opt/catgenome/ngb-cli

wget http://52.38.214.1/distr/latest/ngb-cli.tar.gz
tar -xzf ngb-cli.tar.gz
rm -f ngb-cli.tar.gz
echo "export PATH=$PATH:/opt/catgenome/ngb-cli" >> /etc/profile
source /etc/profile

sed -i '/Connector port="8080"/,/redirectPort="8443" /c\<Connector port="8080" protocol="HTTP/1.1" connectionTimeout="20000" compression="on" compressionMinSize="2048" compressableMimeType="text/html,text/xml,application/json" redirectPort="8443"/>' server.xml

if [ "$OSName" = "Ubuntu" ] && [ "$OSVersion" -ge "14" ] || [ "$OSName" = "CentOS" ] && [ "$OSVersion" -ge "7" ] || [ "$OSName" = "RHEL" ] && [ "$OSVersion" -ge "7" ]
   then     
      systemctl start tomcat
   else
      :
fi
}

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

NGBInstall

exit 0