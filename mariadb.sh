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

    if [[ $(cat /etc/timezone) != $timezone ]]; then
        echo "$timezone" > /etc/timezone
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

cd /tmp

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

chown -Rh mysql. /var/lib/mysql

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
        if [[ -z "$MYSQL_ROOT_PASSWORD" && -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]]
        then
            echo >&2 'error: DB uninitialized and MYSQL_ROOT_PASSWORD not set'
            echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
            exit 1
        fi

        echo 'Running mysql_install_db ...'
        mysql_install_db --datadir="$DATADIR"
        echo 'Finished mysql_install_db'

        # These statements _must_ be on individual lines, and _must_ end with
        # semicolons (no line breaks or comments are permitted).
        # TODO proper SQL escaping on ALL the things D:

        tempSqlFile='/tmp/mysql-first-time.sql'
        cat > "$tempSqlFile" <<-SQLINIT
		DELETE FROM mysql.user;
		CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
		GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
		DROP DATABASE IF EXISTS test;
		SQLINIT

        if [[ "$MYSQL_DATABASE" ]]; then
            echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\`;" \
                        >> "$tempSqlFile"
        fi

        if [[ "$MYSQL_USER" && "$MYSQL_PASSWORD" ]]; then
            echo -n "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED " >>"$tempSqlFile"
            echo "BY '$MYSQL_PASSWORD';" >> "$tempSqlFile"

            if [[ "$MYSQL_DATABASE" ]]; then
                echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';"\
                            >> "$tempSqlFile"
            fi
        fi

        echo 'FLUSH PRIVILEGES;' >> "$tempSqlFile"

        set -- "$@" --init-file="$tempSqlFile"
    fi
    exec mysqld "$@"
fi
