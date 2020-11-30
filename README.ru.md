# docker-pgbouncer

Оригинальный код: https://github.com/sgrinko/docker-pgbouncer

Докер основан на образе ([edoburu/pgbouncer](https://hub.docker.com/r/edoburu/pgbouncer))

Исходный код оригинального образа ([edoburu/docker-pgbouncer](https://github.com/edoburu/docker-pgbouncer))

Отличия:

* запуск выполняется под пользователем postgres у которого gid и uid равен 999 (postgres пользователь с такими номерами используется для всех контейнеров)

* порт для службы назначается 6432 (номер по умолчанию для исходного pgbouncer)

Пример docker-compose файла

```
version: '3.5'
services:
  pgbouncer:

#    image: grufos/pgbouncer:1.14
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
```

Рекомендуется запускать этот докер, как докер-спутник для контейнера с postgres:

```
version: '3.5'
services:
 
  postgres:
 
#    image: grufos/postgres:12.5
    build:
      context: ./docker-postgres
      dockerfile: Dockerfile
    shm_size: '2gb'
    command: |
      -c shared_preload_libraries='plugin_debugger, pg_stat_statements, auto_explain, pg_buffercache, pg_cron, shared_ispell, pg_prewarm'
    volumes:
      - "/var/lib/pgsql/12/data:/var/lib/postgresql/data"
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
      EMAILTO: "PostgreSQL@my_company.ru"
      EMAIL_SERVER: "mail.my_company.ru"
      EMAIL_HOSTNAME: "myhost@noreplay.ru"
      BACKUP_THREADS: "4"
      BACKUP_MODE: "delta"
 
  pgbouncer:
#    image: grufos/pgbouncer:1.14
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
```

Рекомендуемый файл с настройками сохранён в подкаталоге conf

Обратите внимание, что в файле userlist.txt необходимо указать ваш MD5 хэш для пароля пользователя postgres
