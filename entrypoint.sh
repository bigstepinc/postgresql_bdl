#!/bin/bash

if [ "$CONTAINER_DIR" != "" ]; then
   cd /bigstep
   mkdir -p $CONTAINER_DIR
   chmod 700 "$CONTAINER_DIR"
   chown -R postgres "$CONTAINER_DIR"
   mkdir -p /run/postgresql
   chmod g+s /run/postgresql
   chown -R postgres /run/postgresql
   runuser -l postgres -c 'initdb -D $CONTAINER_DIR'

   mkdir /var/lib/postgresql
   chmod 777 /var/lib/postgresql
   chown -R postgres /var/lib/postgresql

   export PGDATA=$CONTAINER_DIR
   chmod 777 $PGDATA/pg_hba.conf
   export authMethod=md5 
   
   { echo; echo "host all all all $authMethod"; } | runuser -l postgres -c 'tee -a "$PGDATA/pg_hba.conf" > /dev/null'

   ln -s /usr/local/lib/libpq.so.5 /usr/lib/libpq.so.5

   runuser -l postgres -c 'pg_ctl -D $PGDATA -o "-c listen_addresses=\'*\'" -w start'

   export POSTGRES_PASSWORD=$(cat \/bigstep\/secrets\/$POSTGRES_HOSTNAME\/POSTGRES_PASSWORD)

   psql=( psql -v ON_ERROR_STOP=1 )

        runuser -l postgres -c '"${psql[@]}" --username postgres <<-EOSQL
                ALTER USER postgres PASSWORD \'$POSTGRES_PASSWORD\' ;
        EOSQL'
        echo

        psql+=( --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" )

        echo

        runuser -l postgres -c 'pg_ctl -D $PGDATA -m fast -w stop'

         echo
         echo 'PostgreSQL init process complete; ready for start up.'
         echo
fi
unset POSTGRES_PASSWORD
# Start PostgreSQL as long-running process
runuser -l postgres -c 'postgres -D $PGDATA'
