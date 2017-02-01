# Fix locale and dpkg in ubuntu 14.04
echo *** Fix Ububtu broken locale ***
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive
locale-gen en_US.UTF-8
dpkg-reconfigure locales
# Install PostGIS
echo *** Installing PostGIS ***
# sudo add-apt-repository -y ppa:ubuntugis/ubuntugis-unstable
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list'
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -
sudo apt-get update -qq
sudo apt-get install -qq -y unzip git
# postgresql postgis
sudo apt-get install -qq -y postgresql postgis postgresql-9.6-postgis-2.3 postgresql-contrib-9.6
sudo apt-get install -qq -y gdal-bin
sudo apt-get install -qq -y libgdal1-dev
gdal-config --version
# create postgis extensions
sudo -u postgres createdb template_postgis
sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.6/contrib/postgis-2.3/postgis.sql >/dev/null 2>&1
sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.6/contrib/postgis-2.3/postgis_comments.sql >/dev/null 2>&1
sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.6/contrib/postgis-2.3/rtpostgis.sql >/dev/null 2>&1
sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.6/contrib/postgis-2.3/raster_comments.sql >/dev/null 2>&1
sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.6/contrib/postgis-2.3/spatial_ref_sys.sql >/dev/null 2>&1
sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.6/contrib/postgis-2.3/topology.sql >/dev/null 2>&1
sudo -u postgres psql -d template_postgis -f /usr/share/postgresql/9.6/contrib/postgis-2.3/topology_comments.sql >/dev/null 2>&1
# add vagrant user to postgres
sudo -u postgres psql -c "CREATE USER vagrant WITH PASSWORD 'vagrant';"
sudo -u postgres psql -c "ALTER USER vagrant with superuser;"
sudo -su vagrant createdb
echo --- allow remote access to postgres host ---
sudo cat >> /etc/postgresql/9.6/main/postgresql.conf <<'EOF'
listen_addresses = '*'
EOF
sudo cat >> /etc/postgresql/9.6/main/pg_hba.conf <<'EOF'
host     all             all             10.10.10.1/24        trust
EOF
echo --- PostGIS Installed - note there will be post-configuration steps needed ---
# Install JRE for GeoServer
echo ' '
echo --- Installing JRE ---
sudo apt-get install -qq -y default-jre
# Config JRE
JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
export JAVA_HOME
echo ' '
echo --- Installing unzip ---
# Install unzip
sudo apt-get install -qq -y unzip
echo ' '
echo --- Setting Up for GeoServer ---
echo "export JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64" >> ~/.bash_profile
echo "export GEOSERVER_HOME=/usr/local/geoserver/" >> ~/.bash_profile
. ~/.profile
sudo rm -rf /usr/local/geoserver/
mkdir /usr/local/geoserver/
sudo chown -R vagrant /usr/local/geoserver/
cd /usr/local
echo ' '
echo --- Downloading GeoServer package - please wait ---
wget -nv -O tmp.zip http://sourceforge.net/projects/geoserver/files/GeoServer/2.10.1/geoserver-2.10.1-bin.zip && unzip -qq tmp.zip -d /usr/local/ && rm tmp.zip
echo ' '
echo --- Package unzipped - configuring GeoServer directory ---
cp -r /usr/local/geoserver-2.10.1/* /usr/local/geoserver && sudo rm -rf /usr/local/geoserver-2.10.1/
echo ' '
echo --- GeoServer Installed ---
echo ' '
sudo apt-get install -qq -y autoconf byobu libtool libgtk-3-dev libpq-dev libproj-dev libxml2-dev libjson-c-dev libcunit1-dev
echo --- Done setting up dependencies ---
echo --- Getting ready to run GeoServer ---
sudo chown -R vagrant /usr/local/geoserver/
cd /usr/local/geoserver/bin
sudo rm /etc/init.d/geoserver
sudo touch /etc/init.d/geoserver
sudo cat >> /etc/init.d/geoserver <<'EOF'
#! /bin/sh
### BEGIN INIT INFO
# Provides:          geoserver
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      S 0 1 6
# Short-Description: GeoServer OGC server
### END INIT INFO

# Geoserver configuration - use /etc/default/geoserver to override these vars
# user that shall run GeoServer
USER=vagrant
JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
export JAVA_HOME
GEOSERVER_DATA_DIR=/usr/local/geoserver/data_dir
GEOSERVER_HOME=/usr/local/geoserver/
export GEOSERVER_HOME
PATH=/usr/sbin:/usr/bin:/sbin:/bin
DESC="GeoServer daemon"
NAME=geoserver
JAVA_OPTS="-Xms128m -Xmx512m -DENABLE_JSONP=true"
DAEMON="$JAVA_HOME/bin/java"
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME
# Read configuration variable file if it is present
[ -r /etc/default/$NAME ] && . /etc/default/$NAME
DAEMON_ARGS="$JAVA_OPTS $DEBUG_OPTS -DGEOSERVER_DATA_DIR=$GEOSERVER_DATA_DIR -Djava.awt.headless=true -jar start.jar"
# Load the VERBOSE setting and other rcS variables
[ -f /etc/default/rcS ] && . /etc/default/rcS
# Define LSB log_* functions.
# Depend on lsb-base (>= 3.0-6) to ensure that this file is present.
. /lib/lsb/init-functions

case "$1" in
  start)
  [ "$VERBOSE" != no ] && log_daemon_msg "Starting $DESC" "$NAME"
  sh /usr/local/geoserver/bin/startup.sh 0<&- &>/dev/null &
  ;;
  stop)
  [ "$VERBOSE" != no ] && log_daemon_msg "Stopping $DESC" "$NAME"
  sh /usr/local/geoserver/bin/shutdown.sh 0<&- &>/dev/null &
  ;;
  restart)
  log_daemon_msg "Restarting $DESC" "$NAME"
  sh /usr/local/geoserver/bin/shutdown.sh 0<&- &>/dev/null &
  sh /usr/local/geoserver/bin/startup.sh 0<&- &>/dev/null &
  ;;
  *)
  echo "Usage: $SCRIPTNAME {start|stop|restart}" >&2
  exit 3
  ;;
esac

:
EOF
sudo chmod +x /etc/init.d/geoserver
sudo update-rc.d geoserver defaults
echo ' '
echo --- Launching GeoServer startup script ---
echo --- This will run in the background with nohup mode ---
echo --- To access the server, use vagrant ssh ---
echo --- To view the web client go to http://localhost:8880/geoserver ---
echo ' '
EOF

sudo chown -R vagrant /usr/local/geoserver/
# sh /usr/local/geoserver/bin/startup.sh 0<&- &>/dev/null &
cd /usr/local/bin
sudo /etc/init.d/postgresql restart
sudo /etc/init.d/geoserver start
