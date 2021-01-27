#!/bin/sh
# Based on https://raw.githubusercontent.com/brainsam/pgbouncer/master/entrypoint.sh

set -e

# Here are some parameters. See all on
# https://pgbouncer.github.io/config.html

PG_CONFIG_DIR=/etc/pgbouncer

if [ -n "$DATABASE_URL" ]; then
  # Thanks to https://stackoverflow.com/a/17287984/146289

  # Allow to pass values like dj-database-url / django-environ accept
  proto="$(echo $DATABASE_URL | grep :// | sed -e's,^\(.*://\).*,\1,g')"
  url="$(echo $DATABASE_URL | sed -e s,$proto,,g)"

  # extract the user and password (if any)
  userpass=$(echo $url | grep @ | sed -r 's/^(.*)@([^@]*)$/\1/')
  DB_PASSWORD="$(echo $userpass | grep : | cut -d: -f2)"
  if [ -n "$DB_PASSWORD" ]; then
    DB_USER=$(echo $userpass | grep : | cut -d: -f1)
  else
    DB_USER=$userpass
  fi

  # extract the host -- updated
  hostport=`echo $url | sed -e s,$userpass@,,g | cut -d/ -f1`
  port=`echo $hostport | grep : | cut -d: -f2`
  if [ -n "$port" ]; then
      DB_HOST=`echo $hostport | grep : | cut -d: -f1`
      DB_PORT=$port
  else
      DB_HOST=$hostport
  fi

  DB_NAME="$(echo $url | grep / | cut -d/ -f2-)"
fi

# the file with the password list does not exist
if [ ! -f ${PG_CONFIG_DIR}/userlist.txt ]; then
  # Write the password with MD5 encryption, to avoid printing it during startup.
  # Notice that `docker inspect` will show unencrypted env variables.
  if [ -n "$DB_PASSWORD" ]; then
    if [ "${AUTH_TYPE:-hba}" != "plain" ]; then
       pass="md5$(echo -n "$DB_PASSWORD${DB_USER:-postgres}" | md5sum | cut -f 1 -d ' ')"
    else
       pass="$DB_PASSWORD"
    fi
    echo "\"${DB_USER:-postgres}\" \"$pass\"" >> ${PG_CONFIG_DIR}/userlist.txt
    echo "Wrote authentication credentials to ${PG_CONFIG_DIR}/userlist.txt"
  fi
fi

if [ ! -f ${PG_CONFIG_DIR}/auth_hba.txt ]; then
  cp -f /usr/local/bin/auth_hba.txt.tmpl  ${PG_CONFIG_DIR}/auth_hba.txt
fi

if [ ! -f ${PG_CONFIG_DIR}/pgbouncer.ini ]; then
  if [ -z "$DB_PASSWORD" ]; then
    cp -f /usr/local/bin/pgbouncer.ini.tmpl ${PG_CONFIG_DIR}/pgbouncer.ini
  fi
fi

if [ ! -f ${PG_CONFIG_DIR}/pgbouncer.ini ]; then
  echo "Create pgbouncer config in ${PG_CONFIG_DIR}"

# Config file is in “ini” format. Section names are between “[” and “]”.
# Lines starting with “;” or “#” are taken as comments and ignored.
# The characters “;” and “#” are not recognized when they appear later in the line.
  printf "\
################## Auto generated ##################
[databases]
${DB_NAME:-*} = host=${DB_HOST:-127.0.0.1} port=${DB_PORT:-5432} auth_user=${DB_USER:-postgres}
${CLIENT_ENCODING:+client_encoding = ${CLIENT_ENCODING}\n}\

[pgbouncer]
logfile = /var/log/pgbouncer/pgbouncer.log
pidfile = /var/run/pgbouncer/pgbouncer.pid
listen_addr = ${LISTEN_ADDR:-0.0.0.0}
listen_port = ${LISTEN_PORT:-6432}
unix_socket_dir = /var/run/postgresql
unix_socket_mode = 0777
auth_file = ${AUTH_FILE:-$PG_CONFIG_DIR/userlist.txt}
auth_hba_file = ${AUTH_HBA_FILE:-$PG_CONFIG_DIR/auth_hba.txt\n}\
auth_type = ${AUTH_TYPE:-hba}
auth_query = ${AUTH_QUERY:-SELECT usename, passwd FROM pg_shadow WHERE usename=$1;\n}\
pool_mode = ${POOL_MODE:-transaction\n}\
max_client_conn = ${MAX_CLIENT_CONN:-10000\n}\
default_pool_size = ${DEFAULT_POOL_SIZE:-5\n}\
${MIN_POOL_SIZE:+min_pool_size = ${MIN_POOL_SIZE}\n}\
${RESERVE_POOL_SIZE:+reserve_pool_size = ${RESERVE_POOL_SIZE}\n}\
${RESERVE_POOL_TIMEOUT:+reserve_pool_timeout = ${RESERVE_POOL_TIMEOUT}\n}\
${MAX_DB_CONNECTIONS:+max_db_connections = ${MAX_DB_CONNECTIONS}\n}\
${MAX_USER_CONNECTIONS:+max_user_connections = ${MAX_USER_CONNECTIONS}\n}\
server_round_robin = ${SERVER_ROUND_ROBIN:-1\n}\
ignore_startup_parameters = ${IGNORE_STARTUP_PARAMETERS:-extra_float_digits}
${DISABLE_PQEXEC:+disable_pqexec = ${DISABLE_PQEXEC}\n}\
${APPLICATION_NAME_ADD_HOST:+application_name_add_host = ${APPLICATION_NAME_ADD_HOST}\n}\

# Log settings
log_connections = ${LOG_CONNECTIONS:-0\n}\
log_disconnections = ${LOG_DISCONNECTIONS:-0\n}\
log_pooler_errors = ${LOG_POOLER_ERRORS:-1\n}\
${LOG_STATS:+log_stats = ${LOG_STATS}\n}\
stats_period = ${STATS_PERIOD:-120\n}\
${VERBOSE:+verbose = ${VERBOSE}\n}\
admin_users = ${ADMIN_USERS:-postgres}
${STATS_USERS:+stats_users = ${STATS_USERS}\n}\

# Connection sanity checks, timeouts
${SERVER_RESET_QUERY:+server_reset_query = ${SERVER_RESET_QUERY}\n}\
${SERVER_RESET_QUERY_ALWAYS:+server_reset_query_always = ${SERVER_RESET_QUERY_ALWAYS}\n}\
${SERVER_CHECK_DELAY:+server_check_delay = ${SERVER_CHECK_DELAY}\n}\
${SERVER_CHECK_QUERY:+server_check_query = ${SERVER_CHECK_QUERY}\n}\
server_lifetime = ${SERVER_LIFETIME:-300\n}\
server_idle_timeout = ${SERVER_IDLE_TIMEOUT:-300\n}\
${SERVER_CONNECT_TIMEOUT:+server_connect_timeout = ${SERVER_CONNECT_TIMEOUT}\n}\
${SERVER_LOGIN_RETRY:+server_login_retry = ${SERVER_LOGIN_RETRY}\n}\
${CLIENT_LOGIN_TIMEOUT:+client_login_timeout = ${CLIENT_LOGIN_TIMEOUT}\n}\
${AUTODB_IDLE_TIMEOUT:+autodb_idle_timeout = ${AUTODB_IDLE_TIMEOUT}\n}\
${DNS_MAX_TTL:+dns_max_ttl = ${DNS_MAX_TTL}\n}\
${DNS_NXDOMAIN_TTL:+dns_nxdomain_ttl = ${DNS_NXDOMAIN_TTL}\n}\

# TLS settings
${CLIENT_TLS_SSLMODE:+client_tls_sslmode = ${CLIENT_TLS_SSLMODE}\n}\
${CLIENT_TLS_KEY_FILE:+client_tls_key_file = ${CLIENT_TLS_KEY_FILE}\n}\
${CLIENT_TLS_CERT_FILE:+client_tls_cert_file = ${CLIENT_TLS_CERT_FILE}\n}\
${CLIENT_TLS_CA_FILE:+client_tls_ca_file = ${CLIENT_TLS_CA_FILE}\n}\
${CLIENT_TLS_PROTOCOLS:+client_tls_protocols = ${CLIENT_TLS_PROTOCOLS}\n}\
${CLIENT_TLS_CIPHERS:+client_tls_ciphers = ${CLIENT_TLS_CIPHERS}\n}\
${CLIENT_TLS_ECDHCURVE:+client_tls_ecdhcurve = ${CLIENT_TLS_ECDHCURVE}\n}\
${CLIENT_TLS_DHEPARAMS:+client_tls_dheparams = ${CLIENT_TLS_DHEPARAMS}\n}\
${SERVER_TLS_SSLMODE:+server_tls_sslmode = ${SERVER_TLS_SSLMODE}\n}\
${SERVER_TLS_CA_FILE:+server_tls_ca_file = ${SERVER_TLS_CA_FILE}\n}\
${SERVER_TLS_KEY_FILE:+server_tls_key_file = ${SERVER_TLS_KEY_FILE}\n}\
${SERVER_TLS_CERT_FILE:+server_tls_cert_file = ${SERVER_TLS_CERT_FILE}\n}\
${SERVER_TLS_PROTOCOLS:+server_tls_protocols = ${SERVER_TLS_PROTOCOLS}\n}\
${SERVER_TLS_CIPHERS:+server_tls_ciphers = ${SERVER_TLS_CIPHERS}\n}\

# Dangerous timeouts
${QUERY_TIMEOUT:+query_timeout = ${QUERY_TIMEOUT}\n}\
${QUERY_WAIT_TIMEOUT:+query_wait_timeout = ${QUERY_WAIT_TIMEOUT}\n}\
${CLIENT_IDLE_TIMEOUT:+client_idle_timeout = ${CLIENT_IDLE_TIMEOUT}\n}\
${IDLE_TRANSACTION_TIMEOUT:+idle_transaction_timeout = ${IDLE_TRANSACTION_TIMEOUT}\n}\
pkt_buf = ${PKT_BUF:-65536\n}\
${MAX_PACKET_SIZE:+max_packet_size = ${MAX_PACKET_SIZE}\n}\
listen_backlog = ${LISTEN_BACKLOG:-1024\n}\
${SBUF_LOOPCNT:+sbuf_loopcnt = ${SBUF_LOOPCNT}\n}\
${SUSPEND_TIMEOUT:+suspend_timeout = ${SUSPEND_TIMEOUT}\n}\
tcp_defer_accept = ${TCP_DEFER_ACCEPT:-30\n}\
tcp_socket_buffer = ${TCP_SOCKET_BUFFER:-65536\n}\
${TCP_KEEPALIVE:+tcp_keepalive = ${TCP_KEEPALIVE}\n}\
tcp_keepcnt = ${TCP_KEEPCNT:-3\n}\
tcp_keepidle = ${TCP_KEEPIDLE:-15\n}\
tcp_keepintvl = ${TCP_KEEPINTVL:-10\n}\
${TCP_USER_TIMEOUT:+tcp_user_timeout = ${TCP_USER_TIMEOUT}\n}\
################## end file ##################
" > ${PG_CONFIG_DIR}/pgbouncer.ini
cat ${PG_CONFIG_DIR}/pgbouncer.ini
echo "Starting $*..."
fi

exec "$@"
