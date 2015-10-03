[![logo](https://raw.githubusercontent.com/dperson/mariadb/master/logo.png)](https://mariadb.org/)

# MariaDB

MariaDB docker container

# What is MariaDB?

MariaDB is a community-developed fork of the MySQL relational database
management system intended to remain free under the GNU GPL. Being a fork of
a leading open source software system, it is notable for being led by the
original developers of MySQL, who forked it due to concerns over its acquisition
by Oracle.[5] Contributors are required to share their copyright with the
MariaDB Foundation.

# How to use this image

When started MariaDB container will listen on port 3306.

## Hosting a MariaDB instance on port 3306

    sudo docker run -p 3306:3306 -d dperson/mariadb

## Configuration

    sudo docker run -it --rm dperson/mariadb -h

    Usage: mariadb.sh [-opt] [command]
    Options (fields in '[]' are optional, '<>' are required):
        -h          This help
        -t ""       Configure timezone
                    possible arg: "[timezone]" - zoneinfo timezone for container

    The 'command' (if provided and valid) will be run instead of mariadb

ENVIROMENT VARIABLES (only available with `docker run`)

 * `MYSQL_ROOT_PASSWORD` - Will set root password when initializing container
 * `MYSQL_ALLOW_EMPTY_PASSWORD` - Allow empty passwords (bad idea)
 * `MYSQL_DATABASE` - Will create DB when initializing container
 * `MYSQL_USER` - Will create user when initializing container
 * `MYSQL_PASSWORD` - Will be used in creating user above
 * `TZ` - As above, configure the zoneinfo timezone, IE `EST5EDT`
 * `USERID` - Set the UID for the DB user
 * `GROUPID` - Set the GID for the DB user

## Examples

Any of the commands can be run at creation with `docker run` or later with
`docker exec mariadb.sh` (as of version 1.3 of docker).

### Setting the Timezone

    sudo docker run -p 3306:3306 -d dperson/mariadb -t EST5EDT

OR using `environment variables`

    sudo docker run -p 3306:3306 -e TZ=EST5EDT -d dperson/mariadb

Will get you the same settings as

    sudo docker run --name db -p 3306:3306 -d dperson/mariadb
    sudo docker exec db mariadb.sh -t EST5EDT ls -AlF /etc/localtime
    sudo docker restart db

## Complex configuration

[Example configs](https://mariadb.com/kb/en/mariadb/documentation/)

If you wish to adapt the default configuration, use something like the following
to copy it from a running container:

    sudo docker cp db:/etc/mysql /some/path

You can use the modified configuration with:

    sudo docker run --name db -p 3306:3306 -v /some/path:/etc/mysql:ro \
                -d dperson/mariadb

# User Feedback

## Issues

If you have any problems with or questions about this image, please contact me
through a [GitHub issue](https://github.com/dperson/mariadb/issues).
