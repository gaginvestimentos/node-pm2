FROM ubuntu:trusty
MAINTAINER Gag Investimentos IT TEAM

# ==============================================================================
# Ubuntu Linux 14.04
# ==============================================================================

# Ignore APT warnings about not having a TTY
ENV DEBIAN_FRONTEND noninteractive

# Ensure UTF-8 locale
RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8
RUN dpkg-reconfigure locales

RUN apt-get update \
  && apt-get upgrade -yq \
  && apt-get -yq install \
      build-essential \
      python \
      wget \
      bindfs \
      vim \
      git-core \
      g++ \
      autoconf \
      file \
      gcc \
      libc-dev \
      make \
      pkg-config \
      re2c \
  && apt-get clean -qq \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN apt-get update && apt-get install -y \
		ca-certificates \
		curl \
		libedit2 \
		libsqlite3-0 \
		libxml2 \
	--no-install-recommends && rm -r /var/lib/apt/lists/*

# ==============================================================================
# Install Postgres, MySQL, MongoDB and more dependencies
# ==============================================================================

ENV PG_MAJOR 9.5
ENV PG_VERSION 9.5.2

# Add PostgreSQL Global Development Group apt source
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ trusty-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list

# Add PGDG repository key
RUN wget -qO - http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc \
    | apt-key add -

RUN  apt-get update -qq \
  && apt-get install -y -qq \
      autoconf \
      imagemagick \
      libbz2-dev \
      libevent-dev \
      libglib2.0-dev \
      libjpeg-dev \
      libmagickcore-dev \
      libmagickwand-dev \
      libncurses-dev \
      libcurl4-openssl-dev \
      libffi-dev \
      libgdbm-dev \
      libpq-dev \
      libreadline-dev libreadline6-dev \
      libssl-dev \
      libtool \
      libxml2-dev \
      libxslt-dev \
      libyaml-dev \
      software-properties-common \
      zlib1g-dev \
      mongodb \
      mysql-client libmysqlclient-dev \
      postgresql-client-$PG_MAJOR \
      sqlite3 libsqlite3-dev \
  && apt-get clean -qq \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN set -xe \
	&& buildDeps=" \
		$PHP_EXTRA_BUILD_DEPS \
		libcurl4-openssl-dev \
		libedit-dev \
		libsqlite3-dev \
		libssl-dev \
		libxml2-dev \
		xz-utils \
	" \
	&& apt-get update && apt-get install -y $buildDeps --no-install-recommends && rm -rf /var/lib/apt/lists/*

ENV PHP_INI_DIR /usr/local/etc/php
RUN mkdir -p $PHP_INI_DIR/conf.d
RUN mkdir -p /usr/src/php
ENV PHP_VERSION 7.0.6
ENV PHP_FILENAME php-7.0.6.tar.xz

RUN cd $HOME && mkdir -p $HOME/tmp

RUN cd $HOME/tmp \
	&& wget  http://www.php.net/distributions/$PHP_FILENAME \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& tar -xf "$PHP_FILENAME" -C /usr/src/php --strip-components=1 \
	&& rm "$PHP_FILENAME" \
	&& cd /usr/src/php \
	&& ./configure \
		--with-config-file-path="$PHP_INI_DIR" \
		--with-config-file-scan-dir="$PHP_INI_DIR/conf.d" \
		$PHP_EXTRA_CONFIGURE_ARGS \
		--disable-cgi \
# --enable-mysqlnd is included here because it's harder to compile after the fact than extensions are (since it's a plugin for several extensions, not an extension in itself)
		--enable-mysqlnd \
# --enable-mbstring is included here because otherwise there's no way to get pecl to use it properly (see https://github.com/docker-library/php/issues/195)
		--enable-mbstring \
		--with-curl \
		--with-libedit \
		--with-openssl \
		--with-zlib \
	&& make -j"$(nproc)" \
	&& make install \
	&& { find /usr/local/bin /usr/local/sbin -type f -executable -exec strip --strip-all '{}' + || true; } \
	&& make clean \
	&& apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $buildDeps

COPY docker-php-ext-* /usr/local/bin/

RUN useradd --home /home/node -m -U -s /bin/bash node

RUN echo 'Defaults !requiretty' >> /etc/sudoers; \
    echo 'node ALL= NOPASSWD: /usr/sbin/dpkg-reconfigure -f noninteractive tzdata, /usr/bin/tee /etc/timezone' >> /etc/sudoers;

RUN mkdir -p /var/www
RUN  chown -R node\:node /var/www && chown -R node\:node /usr/local && chown -R node\:node /usr/src/php && chown -R node\:node /home/node

USER node 

ENV NPM_CONFIG_LOGLEVEL info
ENV NODE_VERSION 4.4.2
ENV PM2_VERSION 1.0.2
ENV TYPESCRIPT_VERSION 1.8.5
ENV TYPINGS_VERSION 0.8.1
ENV GULP_VERSION 3.9.1
ENV MOCHA_VERSION 2.4.5
ENV CHAI_VERSION 3.5.0
ENV JSLINT_VERSION 0.9.6
ENV JSHINT_VERSION 2.9.2
ENV TSLINT_VERSION 3.8.0
ENV HOME /home/node

RUN cd $HOME && mkdir -p $HOME/tmp

RUN cd /home/node &&\
    echo 'export PATH=$HOME/local/bin:$PATH' >> ~/.bashrc

RUN cd /home/node/tmp &&\
    wget https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz &&\
    tar -xzf node-v${NODE_VERSION}-linux-x64.tar.gz -C /usr/local --strip-components=1  &&\
    rm node-v${NODE_VERSION}-linux-x64.tar.gz &&\
    npm install -g pm2@$PM2_VERSION &&\
    npm install -g gulp@$GULP_VERSION &&\
    npm install -g mocha@$MOCHA_VERSION &&\
    npm install -g typescript@$TYPESCRIPT_VERSION &&\
    npm install -g typings@$TYPINGS_VERSION &&\
    npm install -g chai@$CHAI_VERSION &&\
    npm install -g jshint@$JSHINT_VERSION &&\
    npm install -g tslint@$TSLINT_VERSION &&\
    npm install -g jslint@$JSLINT_VERSION
