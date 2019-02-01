FROM php:7.3.0-fpm

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    iputils-ping \
    libicu-dev \
    libmemcached-dev \
    libz-dev \
    libpq-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    libssl-dev \
    libmcrypt-dev \
    libxml2-dev \
    libbz2-dev \
    libjpeg62-turbo-dev \
    librabbitmq-dev \
    libzip-dev \
    curl \
    git \
    subversion \
    unzip \
  && rm -rf /var/lib/apt/lists/*

# Install various PHP extensions
RUN docker-php-ext-configure bcmath --enable-bcmath \
  && docker-php-ext-configure pcntl --enable-pcntl \
  && docker-php-ext-configure pdo_mysql --with-pdo-mysql \
  && docker-php-ext-configure pdo_pgsql --with-pgsql \
  && docker-php-ext-configure mbstring --enable-mbstring \
  && docker-php-ext-configure soap --enable-soap \
  && docker-php-ext-install \
    bcmath \
    intl \
    mbstring \
    mysqli \
    pcntl \
    pdo_mysql \
    pdo_pgsql \
    soap \
    sockets \
    zip \
  && docker-php-ext-configure gd \
    --enable-gd-native-ttf \
    --with-jpeg-dir=/usr/lib \
    --with-freetype-dir=/usr/include/freetype2 \
  && docker-php-ext-install gd \
  && docker-php-ext-install opcache \
  && docker-php-ext-enable opcache \
  && pecl install amqp \
  && docker-php-ext-enable amqp


# ICU - intl requirements for Symfony
# Debian is out of date, and Symfony expects the latest - so build from source, unless a better alternative exists(?)
RUN curl -sS -o /tmp/icu.tar.gz -L http://download.icu-project.org/files/icu4c/58.2/icu4c-58_2-src.tgz \
	&& tar -zxf /tmp/icu.tar.gz -C /tmp \
	&& cd /tmp/icu/source \
	&& ./configure --prefix=/usr/local \
	&& make \
	&& make install

RUN docker-php-ext-configure intl \
    --with-icu-dir=/usr/local \
  && docker-php-ext-install intl


# Install the php memcached extension
RUN curl -L -o /tmp/memcached.tar.gz "https://github.com/php-memcached-dev/php-memcached/archive/v3.1.3.tar.gz" \
  && mkdir -p memcached \
  && tar -C memcached -zxvf /tmp/memcached.tar.gz --strip 1 \
  && ( \
    cd memcached \
    && phpize \
    && ./configure \
    && make -j$(nproc) \
    && make install \
  ) \
  && rm -r memcached \
  && rm /tmp/memcached.tar.gz \
  && docker-php-ext-enable memcached

# Copy opcache configration
COPY ./opcache.ini /usr/local/etc/php/conf.d/opcache.ini

# Copy timezone configration
COPY ./timezone.ini /usr/local/etc/php/conf.d/timezone.ini

# Set timezone
RUN rm /etc/localtime \
  && ln -s /usr/share/zoneinfo/Europe/London /etc/localtime \
  && "date"


# Short open tags fix - another Symfony requirements
COPY ./custom-php.ini /usr/local/etc/php/conf.d/custom-php.ini

# Composer
ENV COMPOSER_HOME /var/www/.composer

RUN curl -sS https://getcomposer.org/installer | php -- \
    --install-dir=/usr/bin \
    --filename=composer \
  && composer self-update

RUN chown -R www-data:www-data /var/www/ \
  && mkdir -p $COMPOSER_HOME/cache \
  && composer global require "hirak/prestissimo:^0.3" \
  && rm -rf $COMPOSER_HOME/cache \
  && mkdir -p $COMPOSER_HOME/cache


RUN rm -rf /var/lib/apt/lists/*

VOLUME $COMPOSER_HOME


# XDebug
# This value must match the name of the 'server' created in PhpStorm for XDebug purposes
# https://confluence.jetbrains.com/display/PhpStorm/Debugging+PHP+CLI+scripts+with+PhpStorm#DebuggingPHPCLIscriptswithPhpStorm-2.StarttheScriptwithDebuggerOptions
ENV PHP_IDE_CONFIG "serverName=Docker"
