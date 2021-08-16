#!/bin/bash

set -x

usage() {
  cat <<EOF
Usage: $0 [-h]

Options
  -h Print this help
  -d Path to database folder which contains database data (default: ./volumes/db/var/lib/postgresql/data)
  -e Path to env-file (default: ./.env)

EOF
}

pre_checks() {
  if ! eval which docker &>/dev/null; then
    echo "Can't find 'docker' command. Is the Docker installed an running?" >&2
    exit 64
  fi

  if ! eval which docker-compose &>/dev/null; then
    echo "Can't find 'docker-compose' command. Is it installed and in your $PATH?" >&2
    exit 64
  fi

  if ! eval which git &>/dev/null; then
    echo "Can't find 'git' command. Is it installed and in your $PATH?" >&2
    exit 64
  fi
}

become_root() {
  # become root while keeping the environment and make script executable
  if [[ $EUID != 0 ]]; then
    chmod +x "$0"
    sudo -E ./"$0" "$@"
    exit $?
  fi
}

info() { printf "\e[1m%s\e[0m\n" "$*" >&2; }

print_warning() {
  echo
  printf "%s\n" "$@" >&2
}

print_error() {
  echo
  printf "%s\n" "$@" >&2
  exit 1
}

choice() {
  while true; do
    echo -n "$1" "(y/N) "
    read -r decision
    if [[ "$decision" =~ (y|Y|j|J) ]]; then
      return 1
    elif [[ "$decision" =~ (n|N) ]]; then
      return 0
    fi
  done
}

check_disk_space() {
  DB_PATH="$1"
  FACTOR="$2"

  info "Checking if enough disk space is available."
  AVAIL=$(df -k --output=avail "$PWD" | tail -n1)
  DB_SIZE=$(du -k -s "$DB_PATH" | awk '{print $1}')

  if [[ "$(stat -f --format="%T" $REPO_PATH)" != 'btrfs' ]]; then
    if [[ "$AVAIL" -gt $(("$DB_SIZE" * "$FACTOR")) ]]; then
      return 0
    else
      return 1
    fi
  else
    print_error "Btrfs is not supported by this script yet. Please check the available" \
                "disk space with 'df -h' and 'du -sh PATH-TO-DB-VOLUME'. To skip the" \
                "check please execute the script with '-s' to continue."
  fi
}

move_old_repo() {
  if [[ ! -f "$REPO_PATH/MOVED" ]]; then
    info "Moving old mattermost-docker repo to backup folder"
    mkdir "$REPO_PATH"/backup
    find "$REPO_PATH" -maxdepth 1 -mindepth 1 \
      -not -name volumes \
      -not -name backup \
      -not -name upgrade-postgres.sh \
      -not -name MOVED \
      -not -name INIT \
      -print0 | xargs -0 mv -t "$REPO_PATH"/backup
    touch "$REPO_PATH/MOVED"
  fi
}

init_new_repo() {
  if [[ ! -f "$REPO_PATH/INIT" ]]; then
    info "Initilizing new docker repo"
    pushd "$REPO_PATH" >/dev/null

    git init
    git remote add origin https://github.com/mattermost/docker
    git pull origin main 1> /dev/null

    popd >/dev/null

    touch "$REPO_PATH/INIT"
  fi

  print_warning "Please open another terminal and copy the 'env.example' to '.env'"
                "and edit this '.env' to match your previous settings."
  while ! choice "Finished editing '.env'? Can we proceed?"; do
    continue
  done
}

backup_database() {
  info "Database backup"
  if choice "Do you want to backup the database with 'pg_dumpall'? This spins up your database temporarily"; then
    mkdir -p "$REPO_PATH"/backup/volumes/db

    info "Attempting to backup database with 'pg_dumpall'"
    #-v $POSTGRES_DATA_PATH:/var/lib/postgresql/data:Z \
    docker run -d --rm --name mattermost-postgres \
      -e POSTGRES_USER="$POSTGRES_USER" \
      -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
      -e POSTGRES_DB="$POSTGRES_DB" \
      -v $REPO_PATH/volumes/db/var/lib/postgresql/data:/var/lib/postgresql/data:Z \
      postgres:9.4-alpine

    docker exec mattermost-postgres /bin/bash -c "pg_dumpall -U \"$POSTGRES_USER\" > /var/lib/postgresql/data/BACKUP_DUMP.sql"
    docker stop -t 5 mattermost-postgres
    mv "$POSTGRES_DATA_PATH/BACKUP_DUMP.sql" "$REPO_PATH"/backup/volumes/db/

    print_warning "Dump written to POSTGRES_DATA_PATH/BACKUP_DUMP.sql (inside container). Moved it to backup/volumes/db."
  fi

  if choice "Do you want to backup the database on filesystem level?"; then
    info "Attempting to backup database with 'cp'..."
    # keeping original structure
    mkdir -p $REPO_PATH/backup/volumes/db/var/lib/postgresql
    cp -a "$POSTGRES_DATA_PATH" "$REPO_PATH"/backup/volumes/db/var/lib/postgresql/

    print_warning "$POSTGRES_DATA_PATH copied into $REPO_PATH/backup/volumes/db/var/lib/postgresql/."
  fi
}

migrate_database() {
  info "Starting migration to Postgres 13."
  mv "$REPO_PATH"/volumes/db/var/lib/postgresql/data "$REPO_PATH"/volumes/db/var/lib/postgresql/data-old
  mkdir "$REPO_PATH"/volumes/db/var/lib/postgresql/data

  # the postgres process is running with user id 999 inside the container
  # to date the container changes them itself
  #chown -R 999:999 "$REPO_PATH"/volumes/db/var/lib/postgresql

  docker run --rm --name postgres-upgrade \
    -e POSTGRES_INITDB_ARGS=" -U $POSTGRES_USER" \
    -e PGUSER="$POSTGRES_USER" \
    -e POSTGRES_USER="$POSTGRES_USER" \
    -e POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    -e POSTGRES_DB="$POSTGRES_DB" \
    -v "$REPO_PATH"/volumes/db/var/lib/postgresql/data-old:/var/lib/postgresql/9.4/data:Z \
    -v "$REPO_PATH"/volumes/db/var/lib/postgresql/data:/var/lib/postgresql/13/data:Z \
    tianon/postgres-upgrade:9.4-to-13
}

#trap '{ rm -rf "$REPO_PATH/MOVED" "$REPO_PATH/INIT"; }' 0

become_root

while getopts srh opt; do
  case "$opt" in
    s)
      skip_check=$OPTARG
      ;;
    r)
      repo_path=$OPTARG
      ;;
    h)
      usage
      exit 0
      ;;
    \?)
      usage >&2
      exit 64
      ;;
  esac
done

shift $((OPTIND - 1))

pre_checks
move_old_repo
init_new_repo
# read in values from env file
. "${REPO_PATH}/.env"
backup_database
migrate_database
