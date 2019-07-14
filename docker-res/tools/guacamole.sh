#!/bin/sh
if [ -z "$1" ]; then
    echo "A port needs to be provided as argument"
    exit 1
fi


# Install tomcat
if [ ! -d "/usr/share/tomcat8/" ]; then
    echo "Installing tomcat8 server."
    # Not working because of user problems: apt-get install tomcat8 tomcat8-admin tomcat8-common tomcat8-user 
    cd /resources/
    wget http://apache.spinellicreations.com/tomcat/tomcat-8/v8.5.43/bin/apache-tomcat-8.5.43.tar.gz
    tar xvzf apache-tomcat-8.5.43.tar.gz
    mkdir -p /usr/share/tomcat8/
    mv apache-tomcat-8.5.43/* /usr/share/tomcat8/
    rm apache-tomcat-8.5.43.tar.gz
    rm -r apache-tomcat-8.5.43/
fi

# Install guacomole server and client
if [ ! -d "/etc/guacamole/" ]; then
    echo "Installing guacamole server."
    cd /resources/
    # Install guacamole dependencies
    apt-get update
    apt-get install -y libcairo2-dev libpng12-dev libjpeg-turbo8-dev \
    libgif-dev libossp-uuid-dev libavcodec-dev libavutil-dev libswscale-dev libfreerdp-dev \
    libpango1.0-dev libssh2-1-dev libvncserver-dev libssl-dev libvorbis-dev libwebp-dev
    wget "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/1.0.0/source/guacamole-server-1.0.0.tar.gz" -O guacamole-server-1.0.0.tar.gz
    tar -xzf guacamole-server-1.0.0.tar.gz
    rm guacamole-server-1.0.0.tar.gz
    cd guacamole-server-1.0.0/
    LD_LIBRARY_PATH="" ./configure --with-init-dir=/etc/init.d
    LD_LIBRARY_PATH="" make
    LD_LIBRARY_PATH="" make install
    ldconfig
    echo "Installing guacamole client."
    # Install guacamole client
    mkdir /etc/guacamole
    wget "http://apache.org/dyn/closer.cgi?action=download&filename=guacamole/1.0.0/binary/guacamole-1.0.0.war" -O /etc/guacamole/guacamole.war
    ln -s /etc/guacamole/guacamole.war /usr/share/tomcat8/webapps/
    # Adapt settings - https://guacamole.apache.org/doc/gug/configuring-guacamole.html
    printf "guacd-hostname: localhost\nguacd-port: 4822\nenable-websocket: true" > /etc/guacamole/guacamole.properties
    printf '
<user-mapping>
 <authorize username="guacadmin"
 password="guacadmin">
  <connection name="vnc-access">
   <protocol>vnc</protocol>
   <param name="hostname">localhost</param>
   <param name="port">5901</param>
   <param name="password">vncpassword</param>
   <param name="autoretry">10</param>
  </connection>
<connection name="rdp-access">
    <protocol>rdp</protocol>
    <param name="hostname">localhost</param>
    <param name="port">3389</param>
    <param name="enable-drive">true</param>
    <param name="console">true</param>
    <param name="ignore-cert">true</param>
    <param name="disable-auth">true</param>
    <param name="resize-method">display-update</param>
</connection>
  <connection name="ssh-access">
    <protocol>ssh</protocol>
    <param name="hostname">localhost</param>
    <param name="port">22</param>
    <param name="username">root</param>
    <param name="enable-sftp">true</param>
</connection>
 </authorize>
</user-mapping>' > /etc/guacamole/user-mapping.xml
    ln -s /etc/guacamole /usr/share/tomcat8/.guacamole
    # add auto redirect to guacomole site for tomcat
    printf '<html lang="en-US"><head><meta charset="UTF-8"><meta http-equiv="refresh" content="0; url=./guacamole/#/?username=guacadmin&password=guacadmin"><title>Redirection</title></head>
    <body><a href="./guacamole/#/?username=guacadmin&password=guacadmin">Redirect</a></body></html>' > /usr/share/tomcat8/webapps/ROOT/index.jsp
fi

# Run
echo "Starting guacamole on port "$1"."
# Change port in tomcat config
sed -i 's/Connector port="[0-9]*"/Connector port="'$1'"/g' /usr/share/tomcat8/conf/server.xml
service guacd restart
/usr/share/tomcat8/bin/catalina.sh run
