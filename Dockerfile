FROM debian:stretch
MAINTAINER David Personette <dperson@gmail.com>

# Install mariadb
RUN export DEBIAN_FRONTEND='noninteractive' && \
    export MAJOR='10.0' && \
    groupadd -r mysql && \
    useradd -c 'MariaDB' -d /var/lib/mysql -g mysql -r mysql && \
    apt-get update -qq && \
    apt-get install -qqy --no-install-recommends gnupg1 && \
    apt-key adv --keyserver pgp.mit.edu --recv-keys \
                199369E5404BD5FC7D2FE43BCBCB082A1BB943DB && \
    /bin/echo -n "deb http://ftp.osuosl.org/pub/mariadb/repo/$MAJOR/debian " \
                >/etc/apt/sources.list.d/mariadb.list && \
    echo "stretch main" >>/etc/apt/sources.list.d/mariadb.list && \
    /bin/echo -e 'Package: *\nPin: release o=MariaDB\nPin-Priority: 999' \
                >/etc/apt/preferences.d/mariadb && \
    { echo mariadb-server-$MAJOR mysql-server/root_password password unused; \
    echo mariadb-server-$MAJOR mysql-server/root_password_again password unused\
                ; } | debconf-set-selections && \
    apt-get update -qq && \
    apt-get install -qqy --no-install-recommends mariadb-server \
                $(apt-get -s dist-upgrade|awk '/^Inst.*ecurity/ {print $2}') &&\
    sed -Ei 's/^(bind-address|log)/#&/' /etc/mysql/my.cnf && \
    sed -i '/skip-external-locking/a \skip-host-cache\nskip-name-resolve' \
                /etc/mysql/my.cnf && \
    sed -i '/= utf8/s/^#//' /etc/mysql/conf.d/mariadb.cnf && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/lib/mysql && \
    { mkdir -p /var/lib/mysql || :; } && \
    chown -Rh mysql. /var/lib/mysql
#    sed -i '/max_binlog_size/a binlog_format           = MIXED' \
#                /etc/mysql/my.cnf && \
COPY mariadb.sh /usr/bin/

EXPOSE 3306

VOLUME ["/etc/mysql", "/var/lib/mysql"]

ENTRYPOINT ["mariadb.sh"]
