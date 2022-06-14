# mysql-encoding-fix.sh

Checks a MySQL database, all tables in the database and the columns in the tables against a given character set and the corresponding collation.

The script shows which entities have the correct encoding set and generates a set of SQL statements for the entities where it doesn't match.

## Usage

    mysql-encoding-fix.sh <options>

### Options

  * -c charset
  * -C collation
  * -d database
  * -h host
  * -q quiet (no colors)
  * -u username

### Examples

Show a color keyed output of the result:

    ./mysql-encoding-fix.sh -d my_database -c utf8mb4 -C utf8mb4_bin

Redirect the output into a .sql file

    ./mysql-encoding-fix.sh -d my_database -c utf8mb4 -C utf8mb4_bin > convert.sql

The .sql file can now be inspected before it is run against the database.

    less convert.sql
    mysql my_database < ./convert.sql

Depending on the size of the database this can take quite a while.