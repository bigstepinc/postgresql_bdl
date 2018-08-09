FROM ubuntu:16.04

ENV PG_MAJOR 9.6
ENV PG_VERSION 9.6.1
ENV PG_SHA256 e5101e0a49141fc12a7018c6dad594694d3a3325f5ab71e93e0e51bd94e51fcd
ENV LD_LIBRARY_PATH /usr/local/lib/
COPY entrypoint.sh /

RUN apt-get update
RUN apt-get install -y wget lbzip2 gcc libreadline6-dev  zlib1g-dev libssl-dev libxml2  \
    libxml2-dev libxslt1.1 libxslt1-dev vim uuid uuid-dev perl make pax-utils
    
RUN useradd postgres

RUN wget -O postgresql.tar.bz2 "https://ftp.postgresql.org/pub/source/v$PG_VERSION/postgresql-$PG_VERSION.tar.bz2" && \
    mkdir -p /usr/src/postgresql && \
    tar --extract --file postgresql.tar.bz2 --directory /usr/src/postgresql --strip-components 1 && \
    rm postgresql.tar.bz2 && \
    cd /usr/src/postgresql && \
     ./configure --enable-integer-datetimes --enable-thread-safety  --enable-tap-tests  --disable-rpath --with-uuid=e2fs \
     --with-gnu-ld  --with-pgport=5432 --with-system-tzdata=/usr/share/zoneinfo --prefix=/usr/local --with-openssl \
     --with-libxml --with-libxslt && \
     make -j "$(getconf _NPROCESSORS_ONLN)" world && \
	  make install-world && \
     make -C contrib install && \
     cd / && \
	  rm -rf /usr/src/postgresql \
	      /usr/local/include/* \
	      /usr/local/share/doc \
		   /usr/local/share/man && \
     mkdir -p /var/run/postgresql && \
     chown -R postgres /var/run/postgresql && \
     chown -R postgres /var/lib && \
     chown -R postgres /usr/local && \
     chown -R postgres /var/run/postgresql && \
     chmod 777 /entrypoint.sh && \
     mkdir -p /bigstep && \
     chown -R postgres /bigstep && \ 
     cd /bigstep && \
     chown -R postgres /usr/share/ && \
     mkdir -p /usr/share/zoneinfo && \
     chown -R postgres /usr/share/zoneinfo 	

USER postgres

EXPOSE 5432

ENTRYPOINT ["/entrypoint.sh"]
