#!/usr/bin/env bash

sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:nginx/stable
sudo add-apt-repository -y ppa:ondrej/php
sudo apt-get -y update

if ! [ -L /var/www ]; then
  rm -rf /var/www
  ln -fs /vagrant/public /var/www
fi

# Install nginx
sudo apt-get install -y nginx=1.12.*

#Install MySQL
sudo debconf-set-selections <<< 'mysql-server-5.7 mysql-server/root_password password rootpass'
sudo debconf-set-selections <<< 'mysql-server-5.7 mysql-server/root_password_again password rootpass'
sudo apt-get -y install mysql-server-5.7

# Install PHP
sudo apt-get -y install php7.2 php7.2-cgi php7.2-fpm php7.2-curl php7.2-mbstring php7.2-mysql

# Stop servers
sudo service nginx stop
sudo service php7.2-fpm stop

# php.ini
if [ ! -f /etc/php/7.2/fpm/php.ini.bkp ]; then
    cp /etc/php/7.2/fpm/php.ini /etc/php/7.2/fpm/php.ini.bkp
else
    rm /etc/php/7.2/fpm/php.ini
    cp /etc/php/7.2/fpm/php.ini.bkp /etc/php/7.2/fpm/php.ini
fi
sed -i.bak 's/^;cgi.fix_pathinfo.*$/cgi.fix_pathinfo = 0/g' /etc/php/7.2/fpm/php.ini

# www.conf
if [ ! -f /etc/php/7.2/fpm/pool.d/www.conf.bkp ]; then
    cp /etc/php/7.2/fpm/pool.d/www.conf /etc/php/7.2/fpm/pool.d/www.conf.bkp
else
    rm /etc/php/7.2/fpm/pool.d/www.conf
    cp /etc/php/7.2/fpm/pool.d/www.conf.bkp /etc/php/7.2/fpm/pool.d/www.conf
fi
sed -i.bak 's/^;security.limit_extensions.*$/security.limit_extensions = .php .php3 .php4 .php5 .php7/g' /etc/php/7.2/fpm/pool.d/www.conf
sed -i.bak 's/^;listen\s.*$/listen = \/var\/run\/php\/php7.2-fpm.sock/g' /etc/php/7.2/fpm/pool.d/www.conf
sed -i.bak 's/^listen.owner.*$/listen.owner = www-data/g' /etc/php/7.2/fpm/pool.d/www.conf
sed -i.bak 's/^listen.group.*$/listen.group = www-data/g' /etc/php/7.2/fpm/pool.d/www.conf
sed -i.bak 's/^;listen.mode.*$/listen.mode = 0660/g' /etc/php/7.2/fpm/pool.d/www.conf

sudo service php7.2-fpm restart

# Nginx
if [ ! -f /etc/nginx/sites-available/vagrant ]; then
    touch /etc/nginx/sites-available/vagrant
fi

if [ -f /etc/nginx/sites-enabled/default ]; then
    rm /etc/nginx/sites-enabled/default
fi

if [ ! -f /etc/nginx/sites-enabled/vagrant ]; then
    ln -s /etc/nginx/sites-available/vagrant /etc/nginx/sites-enabled/vagrant
fi

# Configure host
cat << 'EOF' > /etc/nginx/sites-available/vagrant
server
{
    listen  80;
    root /vagrant/public;
    index index.php index.html index.htm;
    server_name dev.vagrant.com;
    location "/"
    {
        try_files $uri $uri/ /index.php?$args;
    }
    location ~ \.php$
    {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass unix:/var/run/php/php7.2-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME /vagrant/public$fastcgi_script_name;
    }
}
EOF

# Restart servers
sudo service php7.2-fpm restart
sudo service nginx restart
