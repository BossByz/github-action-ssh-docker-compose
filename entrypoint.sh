#!/usb/bin/env bash
set -e

log() {
  echo ">> [local]" $@
}

cleanup() {
  set +e
  log "Killing ssh agent."
  ssh-agent -k
  log "Removing workspace archive."
  rm -f /tmp/workspace.tar.bz2
}
trap cleanup EXIT

log "Packing workspace into archive to transfer onto remote machine."
tar cjvf /tmp/workspace.tar.bz2 --exclude .git --exclude vendor .

log "Launching ssh agent."
eval `ssh-agent -s`

remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { log 'Removing workspace...'; rm -rf \"\$HOME/workspace\" ; } ; log 'Creating workspace directory...' ; mkdir -p \"\$HOME/workspace\" ; trap cleanup EXIT ; log 'Unpacking workspace...' ; sudo apt-get update ; sudo apt-get install bzip2 ;  tar -C \"\$HOME/workspace\" -xjv ; log 'Launching docker-compose...' ; cd \"\$HOME/workspace\" ; docker compose -f \"$DOCKER_COMPOSE_FILENAME\" -p \"$DOCKER_COMPOSE_PREFIX\" pull ; docker-compose -f \"$DOCKER_COMPOSE_FILENAME\" -p \"$DOCKER_COMPOSE_PREFIX\" up -d --remove-orphans --build"
if $DOCKER_COMPOSE_DOWN ; then
  remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { log 'Removing workspace...'; rm -rf \"\$HOME/workspace\" ; } ; log 'Creating workspace directory...' ; mkdir -p \"\$HOME/workspace\" ; trap cleanup EXIT ; log 'Unpacking workspace...' ; tar -C \"\$HOME/workspace\" -xjv ; log 'Launching docker-compose...' ; cd \"\$HOME/workspace\" ; docker compose -f \"$DOCKER_COMPOSE_FILENAME\" -p \"$DOCKER_COMPOSE_PREFIX\" down"
fi

ssh-add <(echo "$SSH_PRIVATE_KEY")

echo ">> [local] Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
  < /tmp/workspace.tar.bz2
