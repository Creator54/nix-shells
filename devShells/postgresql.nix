{ pkgs }:

pkgs.mkShell {
  buildInputs = [ pkgs.postgresql ];
  shellHook = ''
    export PGDATA=$PWD/postgres/data
    export PGHOST=$PWD/postgres
    PGLOG=$PWD/postgres/postgres.log
    export PGPORT=5433
    export PGDATABASE=postgres
    alias psql='psql -h $PGHOST'

    if [ ! -f "$PGDATA/PG_VERSION" ]; then
      echo "Initializing PostgreSQL database..."
      initdb --auth=trust --no-locale --encoding=UTF8 -D "$PGDATA"
    fi

    echo "Starting PostgreSQL server..."
    pg_ctl -D "$PGDATA" -l "$PGLOG" -o "-k $PGHOST -p $PGPORT" start
    
    # Wait for server to be ready and create user database if it doesn't exist
    sleep 1
    if ! psql -lqt | cut -d \| -f 1 | grep -qw "$USER"; then
      createdb "$USER"
      echo "Created database: $USER"
    fi
    
    echo ""
    echo "PostgreSQL is ready!"
    echo "  - Connect with: psql"
    echo "  - List databases: psql -l"
    echo "  - Create database: createdb <name>"
    echo ""

    finish()
    {
      echo "Stopping PostgreSQL server..."
      pg_ctl -D "$PGDATA" stop
    }
    trap finish EXIT
  '';
}
