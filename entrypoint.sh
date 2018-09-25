#!/bin/bash

if [ "$CONTAINER_DIR" != "" ]; then
   useradd $POSTGRES_USER
   useradd $DB_USER
   mkdir -p /usr/share/zoneinfo
   chown -R $POSTGRES_USER /usr/share/zoneinfo 
   mkdir -p $CONTAINER_DIR
   chmod 700 "$CONTAINER_DIR"
   chown -R $POSTGRES_USER "$CONTAINER_DIR"
   mkdir -p /run/postgresql
   chmod g+s /run/postgresql
   chown -R $POSTGRES_USER /run/postgresql
   runuser -l $POSTGRES_USER -c "initdb -D $CONTAINER_DIR"

   mkdir /var/lib/postgresql
   chmod 777 /var/lib/postgresql
   chown -R $POSTGRES_USER /var/lib/postgresql
   
   mkdir /home/$POSTGRES_USER
   
   export PGDATA=$CONTAINER_DIR
   chmod 777 $PGDATA/pg_hba.conf
   export authMethod=md5 
   
   runuser -l $POSTGRES_USER -c '{ echo; echo "host all all all '$authMethod'"; } | tee -a "'$PGDATA/pg_hba.conf'" > /dev/null'

   ln -s /usr/local/lib/libpq.so.5 /usr/lib/libpq.so.5
   
   echo "listen_addresses='*'" >> $PGDATA/postgresql.conf

   runuser -l $POSTGRES_USER -c "pg_ctl -D $PGDATA -o \"-c listen_addresses='*'\" -w start"
   
   export PGPASSWORD=$POSTGRES_PASSWORD 
   
   export POSTGRES_USER=postgres
   export POSTGRES_DB=postgres

   psql=( psql -v ON_ERROR_STOP=1 )
   	
	"${psql[@]}" --username $POSTGRES_USER <<-EOSQL
			ALTER USER $POSTGRES_USER PASSWORD '$POSTGRES_PASSWORD' ;
	EOSQL
	echo

	psql+=( --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" )

	echo
	
	"${psql[@]}" --username $POSTGRES_USER <<-EOSQL
			CREATE USER "$DB_USER" WITH PASSWORD '$DB_PASSWORD';
	EOSQL
	echo

	psql+=( --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" )

	echo

	"${psql[@]}" --username $POSTGRES_USER <<-EOSQL
			CREATE DATABASE "$DB_NAME";
	EOSQL
	echo

	psql+=( --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" )

	echo	
	
	"${psql[@]}" --username $POSTGRES_USER <<-EOSQL
			grant all PRIVILEGES on database "$DB_NAME" to "$DB_USER";
	EOSQL
	echo

	psql+=( --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" )

	echo
	
        runuser -l $POSTGRES_USER -c "pg_ctl -D $PGDATA -m fast -w stop"

        echo
        echo 'PostgreSQL init process complete; ready for start up.'
        echo
fi
unset PGPASSWORD

# Start PostgreSQL as long-running process
runuser -l $POSTGRES_USER -c "postgres -D $PGDATA"
