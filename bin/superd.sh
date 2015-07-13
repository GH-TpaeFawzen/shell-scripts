#!/bin/sh

#
# Supervisor daemon to manage long running processes as a group.
# Terminates all remaining child processes as soon as one child exits.
# Written as entrypoint service for multi-process docker containers.
#
# Usage: ./superd.sh [config_file]
#
# The default superd configuration file is "/usr/local/etc/superd.conf".
# An alternate configuration file can be provided as first argument.
#
# Each line of the superd configuration file must have the following format:
# command [args...]
# Each command will be run by superd as a background process.
# If one command terminates, all commands will be terminated.
# Empty lines and lines starting with a hash (#) will be ignored.
#
# Copyright 2015, Sebastian Tschan
# https://blueimp.net
#
# Licensed under the MIT license:
# http://www.opensource.org/licenses/MIT
#

# Create the directory to store the PIDs for the superd child processes:
mkdir -p /run/superd

# Terminates remaining child processes:
shutdown() {
  # Terminate processes and ignore errors for non-existing process ids:
  kill $(cat /run/superd/*.pid) > /dev/null 2>&1
  # Remove the obsolete PID files;
  rm /run/superd/*.pid
}

# Runs a given command and terminates sibling processes on exit:
run() {
  # Start the given command as background process:
  "$@" &
  # Get the PID of the background process:
  local PID=$!
  # Store the PID with the checksum of the exact command as file name:
  echo $PID > /run/superd/"$(printf '%s' "$@" | sha1sum | cut -f1 -d' ')".pid
  # Wait for the background process to terminate:
  wait $PID
  # Terminate remaining child processes:
  shutdown
}

# Runs commands defined in the given config file:
startup() {
  while read line
  do
    # Skip empty lines and lines starting with a hash (#):
    if [ -z "$line" ] || [ "${line#\#}" != "$line" ]
    then
      continue
    fi
    # Call the run function with the line components as arguments:
    eval "run $line" &
  # Use the given config file as input:
  done < "$1"
}

# Terminate child processes on SIGINT and SIGTERM:
trap 'shutdown; exit' INT TERM

# Use "/usr/local/etc/superd.conf" as default config file:
startup "${1:-/usr/local/etc/superd.conf}"

# Wait for all child processes to terminate:
wait
