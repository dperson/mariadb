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
usage() { local RC="${1:-0}"
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

export DB_DATA_PATH=${DB_DATA_PATH:-/var/lib/mysql}
export DB_ROOT_PASS=${DB_ROOT_PASS:-unused}
export DB_USER=${DB_USER:-mariadb_user}
export DB_PASS=${DB_PASS:-mariadb_user_password}

if [[ $# -ge 1 && -x $(which $1 2>&-) ]]; then
    exec "$@"
elif [[ $# -ge 1 ]]; then
    echo "ERROR: command not found: $1"
    exit 13
elif ps -ef | egrep -v grep | grep -q mysql; then
    echo "Service already running, please restart container to apply changes"
else
    if [[ ! -d "$DB_DATA_PATH/mysql" ]]; then
        mysql_install_db --user=mysql --datadir=$DB_DATA_PATH
        (cd /usr && mysqld_safe --datadir=$DB_DATA_PATH) &
        echo -e '\ny\n$DB_ROOT_PASS\n$DB_ROOT_PASS\n\nn\n\n\n' | \
                    mysql_secure_installation
        echo "CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD' WITH GRANT OPTION;" >/tmp/sql
        echo "GRANT ALL ON *.* TO '$DB_USER'@'%';" >>/tmp/sql
        echo "DELETE FROM mysql.user WHERE User='';" >>/tmp/sql
        echo "DROP DATABASE test;" >> /tmp/sql
        echo "FLUSH PRIVILEGES;" >> /tmp/sql
        cat /tmp/sql | mysql -u root --password="${DB_ROOT_PASS}"
        rm /tmp/sql
        kill %1
    fi
    cd /usr; exec mysqld_safe --datadir=/var/lib/mysql "$@"
fi