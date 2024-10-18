#!/bin/bash

# Update package lists and upgrade all packages
apt-get update
apt-get -y upgrade

# Install necessary packages
apt-get -y install curl gpg sudo software-properties-common ca-certificates gnupg

# Add a new user 'akeneo' with no password and set home directory to /srv
adduser --disabled-password --gecos "" --home /srv akeneo

# Create /srv directory and set ownership to 'akeneo' user
mkdir -p /srv && chown akeneo:akeneo /srv

# Add local hostname mappings to /etc/hosts
echo "127.0.0.1 mysql elasticsearch akeneo-pim.local" >> /etc/hosts

# Add PHP repository
add-apt-repository -y ppa:ondrej/php

# Add Node.js repository and install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/yarnkey.gpg
echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

# Add Elasticsearch GPG key and repository
curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elastic.gpg
echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list

# Add Yarn GPG key and repository
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

# Update package lists again
apt-get -y update 

# Set non-interactive frontend for apt-get
export DEBIAN_FRONTEND=noninteractive

# Install PHP, Composer, Elasticsearch, Node.js, Yarn, Apache, and MySQL
apt-get -y install \
    php8.1 \
    php8.1-xml \
    php8.1-mbstring \
    php8.1-curl \
    php8.1-zip \
    php8.1-intl \
    php8.1-apcu \
    php8.1-bcmath \
    php8.1-gd \
    php8.1-imagick \
    php8.1-mysql \
    composer \
    elasticsearch \
    make \
    yarn \
    nodejs=18.* \
    php8.1-cli \
    php8.1-opcache \
    php8.1-fpm \
    apache2 \
    mysql-server

# Enable Apache modules and PHP configuration
a2enmod rewrite proxy_fcgi
a2enconf php8.1-fpm

# Set PHP 8.1 as the default PHP version
update-alternatives --set php /usr/bin/php8.1

# Create a symbolic link for Composer
ln -s /usr/bin/composer /usr/local/bin/composer

# Set Elasticsearch virtual memory limit
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | tee /etc/sysctl.d/elasticsearch.conf

# Start Elasticsearch and MySQL services
sudo -u elasticsearch nohup /usr/share/elasticsearch/bin/elasticsearch > /var/log/elasticsearch/nohup.out 2>&1 &
/usr/sbin/mysqld &

# Wait for MySQL to start
sleep 5

# Create Akeneo PIM database and user
mysql -u root -e "CREATE DATABASE akeneo_pim; CREATE USER 'akeneo_pim'@'localhost' IDENTIFIED WITH mysql_native_password BY 'akeneo_pim'; GRANT ALL PRIVILEGES ON akeneo_pim.* TO 'akeneo_pim'@'localhost'; FLUSH PRIVILEGES;"

# Update PHP configuration for CLI and FPM
sed -i 's/^memory_limit = .*/memory_limit = 1024M/' /etc/php/8.1/cli/php.ini
sed -i 's/^;date.timezone =.*/date.timezone = Europe\/Helsinki/' /etc/php/8.1/cli/php.ini
sed -i 's/^memory_limit =.*/memory_limit = 512M/' /etc/php/8.1/fpm/php.ini
sed -i 's/^;date.timezone =.*/date.timezone = Europe\/Helsinki/' /etc/php/8.1/fpm/php.ini

# Add 'akeneo' user to 'www-data' group
usermod -aG www-data akeneo

# Create PHP run directory and set ownership
mkdir -p /run/php
chown www-data:www-data /run/php

# Install Akeneo PIM
sudo -u akeneo PIM_ENV=dev composer create-project akeneo/pim-community-standard /srv/pim "7.0.*@stable"
sudo -u akeneo bash -c "export NO_DOCKER=true && cd /srv/pim && make dev"

# Configure Apache virtual host for Akeneo PIM
bash -c 'echo "<VirtualHost *:80>
    ServerName akeneo-pim.local

    DocumentRoot /srv/pim/public
    <Directory /srv/pim/public>
        AllowOverride None
        Require all granted

        Options -MultiViews
        RewriteEngine On
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteRule ^(.*)$ index.php [QSA,L]
    </Directory>

    <Directory /srv/pim/public/bundles>
        RewriteEngine Off
    </Directory>

    <Location \"/index.php\">
        SetHandler \"proxy:unix:/run/php/php8.1-fpm.sock|fcgi://localhost/\"
    </Location>

    SetEnvIf Authorization .+ HTTP_AUTHORIZATION=\$0

    ErrorLog \${APACHE_LOG_DIR}/akeneo-pim_error.log
    LogLevel warn
    CustomLog \${APACHE_LOG_DIR}/akeneo-pim_access.log combined
</VirtualHost>" > /etc/apache2/sites-available/akeneo-pim.local.conf'

# Disable default Apache site and enable Akeneo PIM site
a2dissite 000-default.conf
a2ensite akeneo-pim.local.conf

# Set ownership and permissions for Akeneo PIM directory
sudo chown -R www-data:www-data /srv/pim
sudo chmod -R 755 /srv/pim

# Start PHP-FPM
/usr/sbin/php-fpm8.1 -D

# Configure and start Apache
source /etc/apache2/envvars
export APACHE_RUN_DIR=/var/run/apache2
export APACHE_LOG_DIR=/var/log/apache2
mkdir -p /var/run/apache2
mkdir -p /var/log/apache2
chown -R www-data:www-data /var/run/apache2 /var/log/apache2
nohup /usr/sbin/apache2 -DFOREGROUND &
