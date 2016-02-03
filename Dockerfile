FROM debian:jessie
MAINTAINER Alexander Trost <galexrt@googlemail.com>

ADD includes/ /includes/

RUN useradd -m -d /opt/taiga -s /bin/bash taiga && \
    apt-get -q update && \
    apt-get -q dist-upgrade -y && \
    apt-get install -y curl && \
    curl -sL https://deb.nodesource.com/setup_5.x | bash - && \
    apt-get install -y build-essential binutils-doc autoconf flex bison libjpeg-dev \
        libfreetype6-dev zlib1g-dev libzmq3-dev libgdbm-dev libncurses5-dev automake \
        libtool libffi-dev curl git tmux gettext python3 python3-pip python-dev python3-dev \
        python-pip virtualenvwrapper libxml2-dev libxslt-dev nginx nodejs ruby supervisor \
        postgresql postgresql-contrib postgresql-server-dev-all rabbitmq-server && \
    npm install -g coffee-script gulp bower && \
    pip2 install circus && \
    mv -f /includes/circus.ini /opt/taiga/conf/circus.ini && \
    mv -f /includes/supervisor/* /etc/supervisor/conf.d/ && \
    mv -f /includes/nginx.conf /etc/nginx/nginx.conf && \
    mv -f /includes/taiga-http /etc/nginx/sites-enabled/taiga && \
    rm -f /etc/nginx/sites-enabled/default && \
    apt-get -qq autoremove --purge -y && \
    apt-get -qq clean

USER taiga
RUN cd /opt/taiga && \
    gem install --user-install sass scss-lint && \
    export PATH=~/.gem/ruby/*/bin:$PATH && \
    mkdir -p /opt/taiga/conf/ /opt/taiga/logs && \
    git clone https://github.com/taigaio/taiga-back.git /opt/taiga/taiga-back && \
    cd /opt/taiga/taiga-back && \
    git checkout stable  && \
    bash -c "cd /opt/taiga/taiga-back;source /usr/share/virtualenvwrapper/virtualenvwrapper.sh;mkvirtualenv -p /usr/bin/python3.4 taiga;pip install -r requirements.txt" && \
    git clone https://github.com/taigaio/taiga-front.git /opt/taiga/taiga-front && \
    cd /opt/taiga/taiga-front && \
    git checkout stable && \
    npm install && \
    bower install && \
    git clone https://github.com/taigaio/taiga-events.git /opt/taiga/taiga-events && \
    cd /opt/taiga/taiga-events && \
    npm install

USER root
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /opt/taiga/*/.git && \
    chown -R taiga:taiga /opt/taiga

ADD docker-entrypoint.sh /docker-entrypoint.sh

EXPOSE 80/tcp 443/tcp 8888/tcp

ENTRYPOINT ["/docker-entrypoint.sh"]
