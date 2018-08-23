#!/bin/bash

export DEBIAN_FRONTEND=noninteractive;

#-- User Defined Variables --#
# hostname=''    #Your hostname (e.g. server.example.com)
# sudo_user=''    #Your username
# sudo_user_passwd=''     #your password
# root_passwd=''    #Your new root password
# ssh_port='22'   #Your SSH port if you wish to change it from the default
#-- UDV End --#

install_apache()
{
  echo "Updating packages..."
  sleep 1
  aptitude -y update
  aptitude -y safe-upgrade
  aptitude -y full-upgrade
  aptitude -y install software-properties-common
  echo "Adding ppa:ondrej/apache2 repository as default Apache2 repository..."
  sleep 1
  aptitude -y install apache2
  echo "Activating mod ssl..."
  sleep 1
  a2enmod ssl
  systemctl restart apache2
  echo "Activating mod http2..."
  sleep 1
  a2enmod http2
  systemctl restart apache2
  echo "Activating mod headers..."
  sleep 1
  a2enmod headers
  systemctl restart apache2
  echo "Activating default SSL site on virtual host..."
  sleep 1
  a2ensite default-ssl
  systemctl restart apache2
  curl -I http://127.0.0.1
  echo "It Works!"
  sleep 1
  echo "Apache2 installed..."
  echo "apache2.conf not configured to manage keep alive..."
  echo "Apache2 running mpm_event..."
  echo "Apache2 not configured to run mpm_prefork..."
  sleep 1
  # sudo add-apt-repository ppa:certbot/certbot
  # apt update -y
  # apt upgrade -y
  # sudo apt install python-certbot-apache
}

install_php()
{
  echo "Installing PHP 7.2..."
  echo "Adding ppa:ondrej/php repository as default PHP repository..."
  sleep 1
  sudo add-apt-repository ppa:ondrej/php
  aptitude -y update
  aptitude -y safe-upgrade
  aptitude -y full-upgrade
  echo "Installing PHP 7.2 packages..."
  sleep 1
  aptitude -y install pwgen screen build-essential libcurl3 libmcrypt4 libmemcached11 libxmlrpc-epi0 php libapache2-mod-php7.2 php7.2-cgi php7.2-cli php7.2-common php7.2-curl php7.2-dev php7.2-gd php7.2-gmp php7.2-json php7.2-mysql php7.2-opcache php7.2-pgsql php7.2-pspell php7.2-readline php7.2-recode php7.2-sqlite3 php7.2-tidy php7.2-xml php7.2-xmlrpc libphp7.2-embed php-symfony-polyfill-php72 php7.2-bcmath php7.2-bz2 php7.2-mbstring php7.2-xsl php7.2-zip
  echo "Running php -v command..."
  sleep 1
  php -v
  echo "Installing APCu..."
  sleep 1
  pecl install apcu
  echo "extension=apcu.so" | tee -a /etc/php/7.2/mods-available/cache.ini
  ln -s /etc/php/7.2/mods-available/cache.ini /etc/php/7.2/apache2/conf.d/30-cache.ini
  systemctl restart apache2
  echo "Done! PHP 7.2 installed."
}

install_mysql()
{
  echo "Installing Percona MySQL 5.7 Server..."
  sleep 1
  wget https://repo.percona.com/apt/percona-release_0.1-6.$(lsb_release -sc)_all.deb
  dpkg -i percona-release_0.1-4.$(lsb_release -sc)_all.deb
  echo "Percona MySQL 5.7 Repo added..."
  echo "Percona MySQL 5.7 needs your manual work for security..."
  echo "Keep eyes on the output..."
  sleep 1
  aptitude update
  aptitude -y safe-upgrade
  aptitude -y full-upgrade
  aptitude -y install percona-server-server-5.7
  echo "Done! Percona MySQL 5.7 Server installed..."
  echo "Percona MySQL 5.7 needs your manual work for security..."
  sleep 1
  # debian-sys-maint User for Percona MySQL
  ## https://thecustomizewindows.com/2018/05/steps-to-install-percona-mysql-server-on-ubuntu-18-04-lts/
  # just create en empty file
  touch /etc/mysql/debian.cnf
  cd ~
  # wget my script
  wget https://gist.githubusercontent.com/AbhishekGhosh/1abc7680b5679510929ae2cf9d1717ef/raw/bcb8760b616afb38ab07037578a796ed1a8f7dca/debian-sys-maint.sh
  # execute it
  ls - al
  chmod +x debian-sys-maint.sh
  sh debian-sys-maint.sh
  ## you'll prompted to supply MySQL root password
  # check what is created
  cat /etc/mysql/percona-server.conf.d/90-mysqladmin.cnf 
  cp /etc/mysql/percona-server.conf.d/90-mysqladmin.cnf /etc/mysql/debian.cnf
  # mysql should not have error on restart out of the way
  service mysql restart
  service mysql status
  sudo mysql_secure_installation
}

create_site()
{
    echo "Creating site on Apache2, port 80, at /var/www/html directory..."
    cd /var/www/html
    rm -r /var/www/html/* 
    curl -O https://wordpress.org/latest.tar.gz
    tar -xzxf latest.tar.gz 
    rm latest.tar.gz && cd wordpress 
    mv * ..
    cd .. 
    rm -r wordpress 
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php 
    rm /var/www/html/wp-config-sample.php
    sudo chown -R root:www-data /var/www/html/
    sudo chown -R root:www-data /usr/share/nginx/html 
    sudo find /var/www/html/ -type d -exec chmod g+s {} \; 
    sudo chmod g+w /var/www/html/wp-content 
    sudo chmod -R g+w /var/www/html/wp-content/themes 
    sudo chmod -R g+w /var/www/html/wp-content/plugins
    echo "done."
}

setup_wp()
{

PASS=`pwgen -s 40 1`
mysql -uroot <<MYSQL_SCRIPT
CREATE DATABASE $1;
CREATE USER '$1'@'localhost' IDENTIFIED BY '$PASS';
GRANT ALL PRIVILEGES ON $1.* TO '$1'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
echo "MySQL user created."
echo "Username:   $1"
echo "Password:   $PASS"
}

print_report()
{
  echo "We are trying to autoinstall WordPress if it fails you need to manually work from Web GUI."
  sleep 1
  echo "Database to be used:   localhost"
  echo "Database user:   $1 (and also   root)"
  echo "Database user password:   $PASS for the user $1"
  sed -i "s/'DB_NAME', 'database_name_here'/'DB_NAME', '$1'/g" /var/www/html/wp-config.php;
  sed -i "s/'DB_USER', 'username_here'/'DB_USER', '$1'/g" /var/www/html/wp-config.php;
  sed -i "s/'DB_PASSWORD', 'password_here'/'DB_PASSWORD', '$PASS'/g" /var/www/html/wp-config.php;
  sed -i "s/'DB_HOST', 'localhost'/'DB_HOST', 'localhost'/g" /var/www/html/wp-config.php;
  echo "Visit your domain name or IP and use the information if needed."
}


cleanup()
{
  rm -rf tmp/*
}

#-- Function calls and flow of execution --#

# install apache
install_apache

# install PHP
install_php

# install MySQL
install_mysql

# create the site on nginx
create_site

# setup Wordpress
setup_wp

# print WP installation report
print_report

# clean up tmp
cleanup
