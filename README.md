# docker-pgbouncer

Оригинальный код: https://github.com/sgrinko/docker-pgbouncer

Докер основан на образе ([edoburu/pgbouncer](https://hub.docker.com/r/edoburu/pgbouncer)) за что ему большое спасибо!

Исходный код оригинального образа ([edoburu/docker-pgbouncer](https://github.com/edoburu/docker-pgbouncer))

Отличия:

* запуск выполняется под пользователем postgres у которого gid = 998 и uid равен 999 (postgres пользователь с такими номерами используется для всех контейнеров)

* порт для службы назначается 6432 (номер по умолчанию для исходного pgbouncer)

* по умолчанию включена hba аутентификация

* Если каталог настроек (/etc/pgbouncer) пуст при старте контейнера, то выполняется создание всех необходимых файлов (pgbouncer.ini, auth_hba.txt, userlist.txt).

*userlist.txt* - на формирование влияют переменные окружения:
1-й вариант - использование передачи всей информавции через URI подключения к серверу

| Name | Default value | Description |
|--------------|--------------|--------------|
|DATABASE_URL||Строка по формату: `<сервис>://<пользователь>:<пароль>@<хост>:<порт>/<бд>` пример: `postgresql://postgres:qweasdzxc@127.0.0.1:5432/my_db`|
|AUTH_TYPE|hba|тип аутентификации|

2-й вариант - отдельные переменные

| Name | Default value | Description |
|--------------|--------------|--------------|
|DB_PASSWORD||пароль пользователя (обязателен, для формирования списка пользователей)|
|DB_USER|postgres|имя пользователя для подключения к БД|
|AUTH_TYPE|hba|тип аутентификации|

*auth_hba.txt* - никакие переменные не влияют. Файл создаётся в состоянии:
```
# Allow any user on the local system to connect to any database with
# any database user name using Unix-domain sockets (the default for local
# connections).
#
# TYPE  DATABASE        USER               ADDRESS                 METHOD
local   all             all                                        peer
host    all             all                0.0.0.0/0               md5
host    all             all                ::0/0                   md5
```

*pgbouncer.ini* - почти все параметры можно определить через переменные окружения. Для деталей смотрите файл: entrypoint.sh
В дефолтные значения файла настроек включены следующие значения:

```
[databases]
* = host=127.0.0.1 port=5432 auth_user=postgres
 
[pgbouncer]
logfile = /var/log/pgbouncer/pgbouncer.log
pidfile = /var/run/pgbouncer/pgbouncer.pid
listen_addr = 0.0.0.0
listen_port = 6432
unix_socket_dir = /var/run/postgresql
unix_socket_mode = 0777
auth_file = /etc/pgbouncer/userlist.txt
auth_hba_file = /etc/pgbouncer/auth_hba.txt
auth_type = hba
auth_query = SELECT usename, passwd FROM pg_shadow WHERE usename=/usr/bin/pgbouncer;
pool_mode = transaction
max_client_conn = 10000
default_pool_size = 5
server_round_robin = 1
ignore_startup_parameters = extra_float_digits
 
# Log settings
log_connections = 0
log_disconnections = 0
log_pooler_errors = 1
stats_period = 120
admin_users = postgres
 
# Connection sanity checks, timeouts
server_lifetime = 300
server_idle_timeout = 300
 
# TLS settings
 
# Dangerous timeouts
pkt_buf = 65536
listen_backlog = 1024
tcp_defer_accept = 30
tcp_socket_buffer = 65536
tcp_keepcnt = 3
tcp_keepidle = 15
tcp_keepintvl = 10
```

При наличии в каталоге настроек указанных файлов их содержимое не меняется. В этом случае описанные переменные не используются.

Пример docker-compose файла

```
version: '3.5'
services:
  pgbouncer:
#    image: grufos/pgbouncer:1.15
    build:
      context: ./docker-pgbouncer
      dockerfile: Dockerfile
    volumes:
      - "/etc/pgbouncer/:/etc/pgbouncer/"
      - "/var/log/pgbouncer:/var/log/pgbouncer"
      - "/var/run/postgresql/:/var/run/postgresql/"
      - "/etc/localtime:/etc/localtime"
    ports:
      - "6432:6432"
    environment:
# если в каталоге файлов есть файлы настройки то указанные ниже переменные не обрабатываются.
# если файлы настройки не указываются, то нужно передать в переменных параметры подключения.
# 1-й вариант - использование передачи через URI подключения к серверу
#      - DATABASE_URL=postgresql://postgres:qweasdzxc@127.0.0.1:5432
# 2-й вариант - отдельные переменные.
# Обязательно нужно указывать DB_PASSWORD
      - DB_PASSWORD=qweasdzxc
#      - DB_HOST=127.0.0.1
#      - DB_PORT=5432
#      - DB_USER=postgres
```

Рекомендуется запускать этот докер, как докер-спутник для контейнера с postgres:

```
version: '3.5'
services:
 
  postgres:
#    image: grufos/postgres:13.1
    build:
      context: ./docker-postgres
      dockerfile: Dockerfile
    shm_size: '2gb'
    command: |
      -c shared_preload_libraries='plugin_debugger, pg_stat_statements, auto_explain, pg_buffercache, pg_cron, shared_ispell, pg_prewarm'
    volumes:
      - "/var/lib/pgsql/13/data:/var/lib/postgresql/data"
      - "/var/log/postgresql:/var/log/postgresql"
      - "/var/run/postgresql/:/var/run/postgresql/"
      - "/mnt/pgbak/:/mnt/pgbak/"
    ports:
      - "5432:5432"
    restart: always
    environment:
      POSTGRES_PASSWORD: qweasdzxc
      POSTGRES_HOST_AUTH_METHOD: trust
      DEPLOY_PASSWORD: qweasdzxc
      TZ: "Europe/Moscow"
      EMAILTO: "DBA-PostgreSQL@interfax.ru"
      EMAIL_SERVER: "extra.devel.ifx"
      EMAIL_HOSTNAME: "myhost@noreplay.ru"
      BACKUP_THREADS: "4"
      BACKUP_MODE: "delta"
 
  pgbouncer:
#    image: grufos/pgbouncer:1.15
    build:
      context: ./docker-pgbouncer
      dockerfile: Dockerfile
    volumes:
      - "/etc/pgbouncer/:/etc/pgbouncer/"
      - "/var/log/pgbouncer:/var/log/pgbouncer"
      - "/var/run/postgresql/:/var/run/postgresql/"
      - "/etc/localtime:/etc/localtime"
    ports:
      - "6432:6432"
    restart: always
    depends_on:
      - postgres
    environment:
# если в каталоге файлов есть файлы настройки то указанные ниже переменные не обрабатываются.
# если файлы настройки не указываются, то нужно передать в переменных параметры подключения.
# 1-й вариант - использование передачи через URI подключения к серверу
#      - DATABASE_URL=postgresql://postgres:qweasdzxc@127.0.0.1:5432
# 2-й вариант - отдельные переменные.
# Обязательно нужно указывать DB_PASSWORD
      - DB_PASSWORD=qweasdzxc
#      - DB_HOST=127.0.0.1
#      - DB_PORT=5432
#      - DB_USER=postgres
```

Обратите внимание, что в файле userlist.txt необходимо указать ваш MD5 хэш для пароля пользователя postgres
