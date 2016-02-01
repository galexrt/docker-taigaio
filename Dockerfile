FROM debian:jessie
MAINTAINER Alexander Trost <galexrt@googlemail.com>

ENV DATA_DIR="/data"

ADD docker-entrypoint.sh /entrypoint.sh
ADD includes/ /includes/

RUN useradd -m -d /home/taiga -s /bin/bash taiga && \
    mkdir -p "DATA_DIR" && \
    apt-get -q update && \
    apt-get install -y build-essential binutils-doc autoconf flex bison libjpeg-dev \
        libfreetype6-dev zlib1g-dev libzmq3-dev libgdbm-dev libncurses5-dev automake \
        libtool libffi-dev curl git tmux gettext python3 python3-pip python-dev \
        python3-dev python-pip virtualenvwrapper libxml2-dev libxslt-dev nginx \
        nodejs nodejs-legacy npm supervisor postgresql postgresql-contrib postgresql-server-dev-all && \
    npm install -g coffee-script && \
    mv /includes/supervisor/* /etc/supervisor/conf.d
    rm -f /etc/nginx/sites-enabled/default && \
    mv /includes/taiga-http /etc/nginx/sites-enabled/taiga && \
    apt-get -qq autoremove --purge -y && \
    apt-get -qq clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

USER taiga
RUN mkdir -p /home/taiga/conf/ /home/taiga/logs && \
    git clone https://github.com/taigaio/taiga-back.git /home/taiga/taiga-back && \
    cd /home/taiga/taiga-back && \
    git checkout stable  && \
    bash -c "source /usr/share/virtualenvwrapper/virtualenvwrapper.sh;cd /home/taiga/taiga-back;mkvirtualenv -p /usr/bin/python3.4 taiga;pip install -r requirements.txt" && \
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

EXPOSE 80/tcp 443/tcp
