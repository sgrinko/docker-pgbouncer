# Based on:
# https://hub.docker.com/r/edoburu/pgbouncer
#
FROM alpine:3.11
ARG VERSION=1.14.0

LABEL maintainer="Interfax - https://interfax.ru"

# Inspiration from https://github.com/gmr/alpine-pgbouncer/blob/master/Dockerfile
RUN \
  # Download
  apk --update add autoconf autoconf-doc automake udns udns-dev curl gcc libc-dev libevent libevent-dev libtool make man openssl-dev pkgconfig postgresql-client && \
  curl -o  /tmp/pgbouncer-$VERSION.tar.gz -L https://pgbouncer.github.io/downloads/files/$VERSION/pgbouncer-$VERSION.tar.gz && \
  cd /tmp && \
  # Unpack, compile
  tar xvfz /tmp/pgbouncer-$VERSION.tar.gz && \
  cd pgbouncer-$VERSION && \
  ./configure --prefix=/usr --with-udns && \
  make && \
  # Manual install
  cp pgbouncer /usr/bin && \
  mkdir -p /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer && \
  # entrypoint installs the configuation, allow to write as postgres user
  cp etc/pgbouncer.ini /etc/pgbouncer/pgbouncer.ini.example && \
  cp etc/userlist.txt /etc/pgbouncer/userlist.txt.example && \
  addgroup -g 999 -S postgres 2>/dev/null && \
  adduser -u 999 -S -D -H -h /var/lib/postgresql -g "Postgres user" -s /bin/sh -G postgres postgres 2>/dev/null && \
  chown -R postgres /var/run/pgbouncer /etc/pgbouncer && \
  # Cleanup
  cd /tmp && \
  rm -rf /tmp/pgbouncer*  && \
  apk del --purge autoconf autoconf-doc automake udns-dev curl gcc libc-dev libevent-dev libtool make man libressl-dev pkgconfig

ADD entrypoint.sh /entrypoint.sh

USER postgres

EXPOSE 6432

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
