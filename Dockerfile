FROM php:7.4-apache
WORKDIR /app
COPY . /app
COPY Docker/settings.php /app/web/sites/default/settings.php
COPY Docker/apache2.conf /etc/apache2/apache2.conf
COPY Docker/BaltimoreCyberTrustRoot.crt.pem /app/web/
COPY Docker/uploads.ini /usr/local/etc/php/conf.d
COPY Docker/caa_cron /etc/cron.d/caa_cron
#copying script file and execute permission to script file 
COPY ssh/script.sh script.sh
RUN chmod +x script.sh
#enabled default ssh port for docker:2222
EXPOSE 80 443 2222
#added open-ssh server for installation
RUN set -eux; \
	 \
	if command -v a2enmod; then \
		a2enmod rewrite; \
	fi; \
	 \
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libfreetype6-dev \
		libjpeg-dev \
		libpng-dev \
		libpq-dev \
		vim \
		wget \
		mariadb-client \
		libzip-dev \
		cron \
		openssh-server \
	; \
	 \
	docker-php-ext-configure gd \
		--with-freetype \
		--with-jpeg=/usr \
	; \
	 \
	docker-php-ext-install -j "$(nproc)" \
		gd \
		opcache \
		pdo_mysql \
		pdo_pgsql \
		zip \
		mysqli \
	; \
        \
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"; \
php composer-setup.php; \
mv composer.phar /usr/local/bin/composer; \
php -r "unlink('composer-setup.php');"; \
wget -O drush.phar https://github.com/drush-ops/drush-launcher/releases/download/0.4.2/drush.phar; \
chmod +x drush.phar; \
mv drush.phar /usr/local/bin/drush; \
COMPOSER_MEMORY_LIMIT=-1 composer install; \
composer dump-autoload; \
sed -i "s/^[ \t]*DocumentRoot \/var\/www\/html$/DocumentRoot \/app\/web/" /etc/apache2/sites-available/000-default.conf; \
chown -R www-data. web; \
mkdir /app/web/sites/default/files; \
chmod -R 777 /app/web/sites/default/files; \
ls -l /app/web/sites/default
# assigning root  password       
RUN echo "root:Docker!" | chpasswd
#copying ssh config file 
COPY ssh/sshd_config /etc/ssh/
# Copy and configure the ssh_setup file
RUN mkdir -p /tmp
COPY ssh_setup.sh /tmp
RUN chmod +x /tmp/ssh_setup.sh \
    && (sleep 1;/tmp/ssh_setup.sh 2>&1 > /dev/null)
COPY Docker/.htaccess /app/web/.htaccess
COPY Docker/.htpasswd /etc/apache2/.htpasswd
#enabled script file for run
#CMD ["/usr/sbin/apachectl", "-D", "FOREGROUND"]
CMD ["./script.sh"]
