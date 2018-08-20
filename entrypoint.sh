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
   
   { echo; echo "host all all all $authMethod"; } | runuser -l $POSTGRES_USER -c 'tee -a' "$PGDATA/pg_hba.conf"' > /dev/null'

   ln -s /usr/local/lib/libpq.so.5 /usr/lib/libpq.so.5
   
   echo "listen_addresses='*'" >> $PGDATA/postgresql.conf

   runuser -l $POSTGRES_USER -c "pg_ctl -D $PGDATA -o \"-c listen_addresses='*'\" -w start"

   psql=( psql -v ON_ERROR_STOP=1 )
   	
	if [ "$DB_USER" != 'postgres' ]; then
		"${psql[@]}" --username $POSTGRES_USER <<-EOSQL
			CREATE USER $DB_USER ;
		EOSQL
	else
		"${psql[@]}" --username $POSTGRES_USER <<-EOSQL
			CREATE USER postgres SUPERUSER;
			CREATE DATABASE postgres WITH OWNER postgres;
		EOSQL
	fi
	
	if [ "$POSTGRES_DB" != 'postgres' ]; then
	"${psql[@]}" --username $POSTGRES_USER <<-EOSQL
		CREATE DATABASE "$DB_NAME" ;
	EOSQL
	echo
	fi
   
	"${psql[@]}" --username $POSTGRES_USER <<-EOSQL
		ALTER USER $DB_USER PASSWORD '$DB_PASSWORD' ;
	EOSQL
	echo
	
	"${psql[@]}" --username $POSTGRES_USER <<-EOSQL
		grant all PRIVILEGES on database "$DB_NAME" to "$DB_USER" ;
	EOSQL
	echo

        runuser -l $POSTGRES_USER -c "pg_ctl -D $PGDATA -m fast -w stop"

        echo
        echo 'PostgreSQL init process complete; ready for start up.'
        echo
fi
unset POSTGRES_PASSWORD

# Start PostgreSQL as long-running process
runuser -l $POSTGRES_USER -c "postgres -D $PGDATA"
