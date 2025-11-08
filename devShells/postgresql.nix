{ pkgs }:

pkgs.mkShell {
  buildInputs = [ pkgs.postgresql ];
  shellHook = ''
    export PGDATA=$PWD/postgres/data
    export PGHOST=$PWD/postgres
    PGLOG=$PWD/postgres/postgres.log
    export PGPORT=5433
    alias psql='psql -h $PGHOST'

    if [ ! -f "$PGDATA/PG_VERSION" ]; then
      echo "Initializing PostgreSQL database..."
      initdb --auth=trust --no-locale --encoding=UTF8 -D "$PGDATA"
    fi

    echo "Starting PostgreSQL server..."
    pg_ctl -D "$PGDATA" -l "$PGLOG" -o "-k $PGHOST -p $PGPORT" start

    finish()
    {
      echo "Stopping PostgreSQL server..."
      pg_ctl -D "$PGDATA" stop
    }
    trap finish EXIT
  '';
}
