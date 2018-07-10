FROM php:7-fpm

LABEL maintainer="diego@passbolt.com"

ARG PASSBOLT_VERSION="2.1.0"
ARG PASSBOLT_URL="https://github.com/passbolt/passbolt_api/archive/v${PASSBOLT_VERSION}.tar.gz"

ARG PHP_EXTENSIONS="gd \
      intl \
      pdo_mysql \
      xsl"


ARG PHP_EXTENSIONS="gd \
      intl \
      pdo_mysql \
      xsl"

ARG PECL_PASSBOLT_EXTENSIONS="gnupg \
      redis \
      mcrypt"

ARG PASSBOLT_DEV_PACKAGES="libgpgme11-dev \
      libpng-dev \
      libjpeg62-turbo-dev \
      libicu-dev \
      libxslt1-dev \
      libmcrypt-dev \
      unzip \
      git"

ENV PECL_BASE_URL="https://pecl.php.net/get"
ENV PHP_EXT_DIR="/usr/src/php/ext"

WORKDIR /var/www/passbolt
RUN apt-get update \
    && apt-get -y install --no-install-recommends $PASSBOLT_DEV_PACKAGES \
         nginx \
         gnupg \
         libgpgme11 \
         libmcrypt4 \
         mysql-client \
         supervisor \
         netcat \
         cron \
    && mkdir /home/www-data \
    && chown -R root:root /home/www-data \
    && docker-php-source extract \
    && for i in $PECL_PASSBOLT_EXTENSIONS; do \
         mkdir $PHP_EXT_DIR/$i; \
         curl -sSL $PECL_BASE_URL/$i | tar zxf - -C $PHP_EXT_DIR/$i --strip-components 1; \
       done \
    && docker-php-ext-configure gd --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j4 $PHP_EXTENSIONS $PECL_PASSBOLT_EXTENSIONS \
    && docker-php-ext-enable $PHP_EXTENSIONS $PECL_PASSBOLT_EXTENSIONS \
    && docker-php-source delete \
    && EXPECTED_SIGNATURE=$(curl -s https://composer.github.io/installer.sig) \
    && curl -o composer-setup.php https://getcomposer.org/installer \
    && ACTUAL_SIGNATURE=$(php -r "echo hash_file('SHA384', 'composer-setup.php');") \
    && if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then \
         >&2 echo 'ERROR: Invalid installer signature'; \
         rm composer-setup.php; \
         exit 1; \
       fi \
    && php composer-setup.php \
    && mv composer.phar /usr/local/bin/composer \
    && curl -sSL $PASSBOLT_URL | tar zxf - -C . --strip-components 1 \
    && composer install -n --no-dev --optimize-autoloader \
    && sed -i -e '/user/!b' -e '/www-data/!b' -e '/www-data/d' /etc/nginx/nginx.conf \
    && sed -i 's:pid /run/nginx.pid:pid /var/cache/nginx/nginx.pid:' /etc/nginx/nginx.conf \
    && sed -i 's!/var/run/nginx.pid!/var/cache/nginx/nginx.pid!g' /etc/nginx/nginx.conf \
    && sed -i "/^http {/a \    proxy_temp_path /var/cache/nginx/proxy_temp;\n    client_body_temp_path /var/cache/nginx/client_temp;\n    fastcgi_temp_path /var/cache/nginx/fastcgi_temp;\n    uwsgi_temp_path /var/cache/nginx/uwsgi_temp;\n    scgi_temp_path /var/cache/nginx/scgi_temp;\n" /etc/nginx/nginx.conf \
    && sed -i 's:/run/nginx.pid:/var/cache/nginx/nginx.pid:' /etc/init.d/nginx \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && sed -i 's:/var/run/crond.pid:/var/cache/crond/crond.pid:' /etc/init.d/cron \
    && chown -R root:root . \
    && chmod -R g+w . \
    && mkdir -p /var/cache/nginx \
    && chown root:root /var/cache/nginx \
    && chmod g+rw /var/cache/nginx \
    && chmod -R g+w /var/log/nginx \
    && mkdir -p /var/cache/crond \
    && chown root:root /var/cache/crond \
    && chmod g+rw /var/cache/crond \
    && mkdir -p /var/cache/supervisor \
    && chown -R root:root /var/cache/supervisor \
    && chmod -R g+w  /var/cache/supervisor \
    && chmod -R g+w /var/log/supervisor \
    && mkdir -p /etc/ssl/passbolt-certs \
    && chown root:root /etc/ssl/passbolt-certs \
    && chmod g+rw /etc/ssl/passbolt-certs \
    && chmod 775 $(find /var/www/passbolt/tmp -type d) \
    && chmod 664 $(find /var/www/passbolt/tmp -type f) \
    && chmod 775 $(find /var/www/passbolt/webroot/img/public -type d) \
    && chmod 664 $(find /var/www/passbolt/webroot/img/public -type f) \
    && chmod -R g+rw /home/www-data \
    && chmod g=u /etc/passwd \
    && rm /etc/nginx/sites-enabled/default \
    && apt-get purge -y --auto-remove $PASSBOLT_DEV_PACKAGES \
    && rm -rf /var/lib/apt/lists/* \
    && rm /usr/local/bin/composer

COPY conf/passbolt.conf /etc/nginx/conf.d/default.conf
COPY conf/supervisord.conf /etc/supervisor/supervisord.conf
COPY bin/docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 8080 8443

CMD ["/docker-entrypoint.sh"]
