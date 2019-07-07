FROM alpine
MAINTAINER David Personette <dperson@gmail.com>

# Install mariadb
RUN apk --no-cache --no-progress upgrade && \
    apk --no-cache --no-progress add bash mariadb mariadb-client tini shadow \
                tzdata && \
    sed -i '/symbolic-links/a \skip-external-locking\nskip-host-cache\nskip-name-resolve' \
                /etc/my.cnf && \
    rm -rf /tmp/* $file moinmoin raw
COPY mariadb.sh /usr/bin/

EXPOSE 3306

VOLUME ["/etc/mysql", "/var/lib/mysql"]

ENTRYPOINT ["mariadb.sh"]