FROM debian:jessie
MAINTAINER Alexander Trost <galexrt@googlemail.com>

ENV DATA_DIR="/data"

ADD docker-entrypoint.sh /entrypoint.sh

RUN useradd -m -d /home/taiga -s /bin/bash taiga && \
    mkdir -p "DATA_DIR" /home/taiga/conf/ /home/taiga/logs && \
    apt-get -q update && \
    apt-get install -y build-essential binutils-doc autoconf flex bison libjpeg-dev \
        libfreetype6-dev zlib1g-dev libzmq3-dev libgdbm-dev libncurses5-dev automake \
        libtool libffi-dev curl git tmux gettext python3 python3-pip python-dev \
        python3-dev python-pip virtualenvwrapper libxml2-dev libxslt-dev nginx \
        nodejs nodejs-legacy npm supervisord && \
    npm install -g coffee-script && \
    rm /etc/nginx/sites-enabled/default && \
    apt-get -qq autoremove --purge -y && \
    apt-get -qq clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER taiga
RUN git clone https://github.com/taigaio/taiga-back.git /home/taiga/taiga-back && \
    cd /home/taiga/taiga-back  && \
    git checkout stable  && \
    mkvirtualenv -p /usr/bin/python3.4 taiga && \
    pip install -r requirements.txt && \
    cd /home/taiga && \
    git clone https://github.com/taigaio/taiga-front-dist.git taiga-front-dist && \
    cd /home/taiga/taiga-front-dist && \
    git checkout stable && \
    cd /home/taiga && \
    git clone https://github.com/taigaio/taiga-events.git taiga-events && \
    cd /home/taiga/taiga-events && \
    npm install

USER root
ENTRYPOINT ["/entrypoint.sh"]
