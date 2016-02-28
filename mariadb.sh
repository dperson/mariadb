#!/usr/bin/env bash
#===============================================================================
#          FILE: mariadb.sh
#
#         USAGE: ./mariadb.sh
#
#   DESCRIPTION: Entrypoint for mariadb docker container
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: David Personette (dperson@gmail.com),
#  ORGANIZATION:
#       CREATED: 2014-10-16 02:56
#      REVISION: 1.0
#===============================================================================

set -o nounset                              # Treat unset variables as an error

### timezone: Set the timezone for the container
# Arguments:
#   timezone) for example EST5EDT
# Return: the correct zoneinfo file will be symlinked into place
timezone() { local timezone="${1:-EST5EDT}"
    [[ -e /usr/share/zoneinfo/$timezone ]] || {
        echo "ERROR: invalid timezone specified: $timezone" >&2
        return
    }

    if [[ -w /etc/timezone && $(cat /etc/timezone) != $timezone ]]; then
        echo "$timezone" >/etc/timezone
        ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
        dpkg-reconfigure -f noninteractive tzdata >/dev/null 2>&1
    fi
}

### usage: Help
# Arguments:
#   none)
# Return: Help text
usage() { local RC=${1:-0}
    echo "Usage: ${0##*/} [-opt] [command]
Options (fields in '[]' are optional, '<>' are required):
    -h          This help
    -T \"\"       Configure timezone
                possible arg: \"[timezone]\" - zoneinfo timezone for container

The 'command' (if provided and valid) will be run instead of mariadb
" >&2
    exit $RC
}

while getopts ":ht:" opt; do
    case "$opt" in
        h) usage ;;
        t) timezone "$OPTARG" ;;
        "?") echo "Unknown option: -$OPTARG"; usage 1 ;;
        ":") echo "No argument value for option: -$OPTARG"; usage 2 ;;
    esac
done
shift $(( OPTIND - 1 ))

[[ "${TZ:-""}" ]] && timezone "$TZ"
[[ "${USERID:-""}" =~ ^[0-9]+$ ]] && usermod -u $USERID -o mysql
[[ "${GROUPID:-""}" =~ ^[0-9]+$ ]] && groupmod -g $GROUPID -o mysql

chown -Rh mysql. /run/mysqld /var/lib/mysql /var/log/mysql* 2>&1 |
            grep -iv 'Read-only' || :

if [[ $# -ge 1 && -x $(which $1 2>&-) ]]; then
    exec "$@"
elif [[ $# -ge 1 ]]; then
    echo "ERROR: command not found: $1"
    exit 13
elif ps -ef | egrep -v grep | grep -q mysql; then
    echo "Service already running, please restart container to apply changes"
else
    # read DATADIR from the MySQL config
    DATADIR="$(mysqld --verbose --help 2>/dev/null |
                awk '$1 == "datadir" {print $2; exit;}')"

    if [[ ! -d "$DATADIR/mysql" ]]; then
        if [[ -z "$SQL_ROOT_PASSWORD" && -z "$SQL_ALLOW_EMPTY_PASSWORD" ]]
        then
            echo >&2 'error: DB uninitialized and SQL_ROOT_PASSWORD not set'
            echo >&2 '  Did you forget to add -e SQL_ROOT_PASSWORD=... ?'
            exit 1
        fi

        echo 'Initializing database'
        mysql_install_db --datadir="$DATADIR"
        echo 'Database initialized'

        mysqld --skip-networking &
        pid="$!"

        mysql=( mysql --protocol=socket -uroot )

        echo 'MySQL init process in progress...'
        for i in {30..0}; do
            if echo 'SELECT 1' | "${mysql[@]}" &>/dev/null; then
                break
            fi
            sleep 1
        done
        if [[ "$i" -eq 0 ]]; then
            echo >&2 'MySQL init process failed.'
            exit 1
        fi

        if [[ -z "$SQL_INITDB_SKIP_TZINFO" ]]; then
            # sed is for https://bugs.mysql.com/bug.php?id=20545
            mysql_tzinfo_to_sql /usr/share/zoneinfo |
                sed 's/Local time zone must be set--see zic manual page/FCTY/' |
                "${mysql[@]}" mysql
        fi

        "${mysql[@]}" <<-EOSQL
		-- What's done in this file shouldn't be replicated
		--  or products like mysql-fabric won't work
		SET @@SESSION.SQL_LOG_BIN=0;

		DELETE FROM mysql.user;
		CREATE USER 'root'@'%' IDENTIFIED BY '${SQL_ROOT_PASSWORD}';
		GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
		DROP DATABASE IF EXISTS test;
		FLUSH PRIVILEGES;
		EOSQL

        if [[ "$SQL_ROOT_PASSWORD" ]]; then
            mysql+=( -p"${SQL_ROOT_PASSWORD}" )
        fi

        if [[ "$DATABASE" ]]; then
            echo "CREATE DATABASE IF NOT EXISTS '$DATABASE';" | "${mysql[@]}"
            mysql+=( "$DATABASE" )
        fi

        if [[ "$SQL_USER" && "$SQL_PASSWORD" ]]; then
            echo "CREATE USER '$SQL_USER'@'%' IDENTIFIED BY '$SQL_PASSWORD';" |
                        "${mysql[@]}"

            if [[ "$DATABASE" ]]; then
                echo "GRANT ALL ON \`$DATABASE\`.* TO '$SQL_USER'@'%';" |
                            "${mysql[@]}"
            fi

            echo 'FLUSH PRIVILEGES;' | "${mysql[@]}"
        fi

        echo
        for f in /docker-entrypoint-initdb.d/*; do
            case "$f" in
                *.sh)  echo "$0: running $f"; . "$f" ;;
                *.sql) echo "$0: running $f"; "${mysql[@]}" < "$f" && echo ;;
                *)     echo "$0: ignoring $f" ;;
            esac
            echo
        done

        if ! kill -s TERM "$pid" || ! wait "$pid"; then
            echo >&2 'MySQL init process failed.'
            exit 1
        fi

        echo
        echo 'MySQL init process done. Ready for start up.'
        echo
    fi
    exec mysqld "$@"
fi