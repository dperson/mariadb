FROM debian:jessie
MAINTAINER David Personette <dperson@dperson.com>

# Install mariadb
RUN export DEBIAN_FRONTEND='noninteractive' && \
    export VERSION='10.0' && \
    groupadd -r mysql && useradd -r -g mysql mysql && \
    apt-key adv --keyserver pgp.mit.edu --recv-keys \
                199369E5404BD5FC7D2FE43BCBCB082A1BB943DB && \
    echo -n "deb http://ftp.osuosl.org/pub/mariadb/repo/$VERSION/debian " > \
                /etc/apt/sources.list.d/mariadb.list && \
    echo "wheezy main" >> /etc/apt/sources.list.d/mariadb.list && \
    apt-get update -qq && \
    apt-get install -qqy --no-install-recommends mariadb-server \
                $(apt-get -s dist-upgrade|awk '/^Inst.*ecurity/ {print $2}') &&\
    sed -ri 's/^(bind-address|skip-networking)/;\1/' /etc/mysql/my.cnf && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/lib/mysql && \
    mkdir /var/lib/mysql
COPY mariadb.sh /usr/bin/

EXPOSE 3306

VOLUME ["/var/lib/mysql"]

ENTRYPOINT ["mariadb.sh"]
