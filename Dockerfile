FROM alpine
MAINTAINER David Personette <dperson@gmail.com>

# Install mariadb
RUN apk --no-cache --no-progress upgrade && \
    apk --no-cache --no-progress add bash mariadb mariadb-client tini shadow \
                tzdata && \
    sed -i '/skip-external-locking/a \skip-host-cache\nskip-name-resolve' \
                /etc/mysql/my.cnf && \
    rm -rf /tmp/* $file moinmoin raw
COPY mariadb.sh /usr/bin/

EXPOSE 3306

VOLUME ["/etc/mysql", "/var/lib/mysql"]

ENTRYPOINT ["mariadb.sh"]