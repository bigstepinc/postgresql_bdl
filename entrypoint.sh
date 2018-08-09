#!/bin/bash

if [ "$CONTAINER_DIR" != "" ]; then
   mkdir -p $CONTAINER_DIR
   chmod 700 "$CONTAINER_DIR"
   chown -R postgres "$CONTAINER_DIR"
   mkdir -p /run/postgresql
   chmod g+s /run/postgresql
   chown -R postgres /run/postgresql
   su-exec postgres initdb -D $CONTAINER_DIR
   
   mkdir /var/lib/postgresql
   chmod 777 /var/lib/postgresql
   chown -R postgres /var/lib/postgresql
    
   export PGDATA=$CONTAINER_DIR
   export authMethod=md5 
   
   { echo; echo "host all all all $authMethod"; } | su-exec postgres tee -a "$PGDATA/pg_hba.conf" > /dev/null
    
   su-exec postgres pg_ctl -D "$PGDATA" \
			-o "-c listen_addresses='*'" \
			-w start
         
   psql=( psql -v ON_ERROR_STOP=1 )

	"${psql[@]}" --username postgres <<-EOSQL
		ALTER USER postgres PASSWORD '$POSTGRES_PASSWORD' ;
	EOSQL
	echo
		
	psql+=( --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" )

	echo
      
         su-exec postgres pg_ctl -D "$PGDATA" -m fast -w stop

	 echo
	 echo 'PostgreSQL init process complete; ready for start up.'
	 echo
fi

# Start PostgreSQL as long-running process
su-exec postgres postgres -D $PGDATA
