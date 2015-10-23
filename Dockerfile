FROM debian:jessie
MAINTAINER David Personette <dperson@dperson.com>

# Install mariadb
RUN export DEBIAN_FRONTEND='noninteractive' && \
    export VERSION='10.0' && \
    groupadd -r mysql && useradd -r -g mysql mysql && \
    apt-key adv --keyserver pgp.mit.edu --recv-keys \
                199369E5404BD5FC7D2FE43BCBCB082A1BB943DB && \
    /bin/echo -n "deb http://ftp.osuosl.org/pub/mariadb/repo/$VERSION/debian " \
                >/etc/apt/sources.list.d/mariadb.list && \
    echo "jessie main" >> /etc/apt/sources.list.d/mariadb.list && \
    apt-get update -qq && \
    apt-get install -qqy --no-install-recommends mariadb-server \
                $(apt-get -s dist-upgrade|awk '/^Inst.*ecurity/ {print $2}') &&\
    sed -ri 's/^(bind-address|skip-networking)/#\1/' /etc/mysql/my.cnf && \
    sed -i '/max_binlog_size/a binlog_format           = MIXED' \
                /etc/mysql/my.cnf && \
    sed -ri '/= utf8/s/^#//' /etc/mysql/conf.d/mariadb.cnf && \
    mkdir -p /var/lib/mysql || : && \
    chown -Rh mysql. /var/lib/mysql && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/lib/mysql/*
COPY mariadb.sh /usr/bin/

EXPOSE 3306

VOLUME ["/run", "/tmp", "/var/cache", "/var/lib", "/var/log", "/var/tmp", \
            "/etc/mysql"]

ENTRYPOINT ["mariadb.sh"]
