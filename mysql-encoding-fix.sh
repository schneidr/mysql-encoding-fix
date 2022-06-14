#!/usr/bin/env bash
set -e

usage() {
    cat <<USAGE
Usage: $0 <options>
Options:
  -d database
  -h host
  -u username
  -c charset
  -C collation
  -q quiet (no colors)
USAGE
    exit 1
}

USE_COLORS=1

[[ -f /dev/stdout ]] && USE_COLORS=0

while getopts "qh:u:c:C:d:D:" option; do
    case "${option}" in
        h)
            MYSQLHOST="-h ${OPTARG}"
            ;;
        u)
            MYSQLUSER="-u ${OPTARG}"
            ;;
        c)
            CHARSET="${OPTARG}"
            ;;
        C)
            COLLATION="${OPTARG}"
            ;;
        d)
            DATABASE="${OPTARG}"
            ;;
        q)
            USE_COLORS=0
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ "$USE_COLORS" -eq 1 ]; then
    RESET="\e[0m"
    RED="\e[0;91m"
    GREEN="\e[0;92m"
    YELLOW="\e[1;33m"
    GRAY="\e[1;30m"
fi

mysql_cmd() {
    OUTPUT=$(mysql "$MYSQLHOST" "$MYSQLUSER" --batch --skip-column-names --database "$DATABASE" -e "$@")
    echo "$OUTPUT"
}

comment() {
    [ "$2" == "$3" ] && COLOR=$GREEN || COLOR=$RED
    echo -e "$GRAY-- $1 $COLOR$2$RESET"
}

comment "Wanted charset:    $YELLOW$CHARSET"
comment "Wanted collation:  $YELLOW$COLLATION"
echo

SERVER_CHARSET=$(mysql_cmd "SELECT @@character_set_database;")
SERVER_COLLATION=$(mysql_cmd "SELECT @@collation_database;")

comment "global default charset:   " "$SERVER_CHARSET" "$CHARSET"
comment "global default collation: " "$SERVER_COLLATION" "$COLLATION"
echo
comment "Checking database: $YELLOW$DATABASE"
echo "USE $DATABASE;"

DB_CHARSET=$(mysql_cmd "SELECT default_character_set_name FROM information_schema.SCHEMATA WHERE schema_name = '$DATABASE';")
comment "database charset: " "$DB_CHARSET" "$CHARSET"

DB_COLLATION=$(mysql_cmd "SELECT default_collation_name FROM information_schema.SCHEMATA WHERE schema_name = '$DATABASE';")
comment "database collation: " "$DB_COLLATION" "$COLLATION"

if ! [[ "$DB_CHARSET" == "$CHARSET" && "$DB_COLLATION" == "$COLLATION" ]]; then
    echo "ALTER DATABASE \`$DATABASE\` CHARACTER SET $CHARSET COLLATE $COLLATION;"
fi

DB_TABLES=$(mysql_cmd "SELECT T.table_name, CCSA.character_set_name, CCSA.collation_name FROM information_schema.\`TABLES\` T, information_schema.\`COLLATION_CHARACTER_SET_APPLICABILITY\` CCSA WHERE CCSA.collation_name = T.table_collation AND T.table_schema='$DATABASE'")
while read -r TABLE_NAME TABLE_CHARSET TABLE_COLLATION
do
    echo 
    comment "table $YELLOW$TABLE_NAME"
    comment "  charset:     " "$TABLE_CHARSET" "$CHARSET"
    comment "  collation:   " "$TABLE_COLLATION" "$COLLATION"
    if ! [[ "$TABLE_CHARSET" == "$CHARSET" && "$TABLE_COLLATION" == "$COLLATION" ]]; then
        echo "ALTER TABLE \`$TABLE_NAME\` CONVERT TO CHARACTER SET $CHARSET COLLATE $COLLATION;"
    fi
    TABLE_COLUMNS=$(mysql_cmd "SELECT column_name,character_set_name,collation_name,COLUMN_TYPE FROM information_schema.columns WHERE table_name = '$TABLE_NAME' AND TABLE_SCHEMA='$DATABASE' AND character_set_name IS NOT NULL;")
    while read -r COLUMN_NAME COLUMN_CHARSET COLUMN_COLLATION COLUMN_TYPE
    do
        [ -z "$COLUMN_NAME" ] && continue
        comment "column $YELLOW$COLUMN_NAME"
        comment "    charset:     " "$COLUMN_CHARSET" "$CHARSET"
        comment "    collation:   " "$COLUMN_COLLATION" "$COLLATION"
        if ! [[ "$COLUMN_CHARSET" == "$CHARSET" && "$COLUMN_COLLATION" == "$COLLATION" ]]; then
            echo "ALTER TABLE \`$TABLE_NAME\` MODIFY \`$COLUMN_NAME\` $COLUMN_TYPE CHARACTER SET $CHARSET COLLATE $COLLATION;"
        fi
    done <<< "$TABLE_COLUMNS"
done <<< "$DB_TABLES"
