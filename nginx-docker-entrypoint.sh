#!/bin/sh -e

# Remove the pidfile (it is assumed that nginx is not running when launching this script).
# When restarting the container, nginx-canary.sh would fail if the pidfile exists and targets a wrong/unexistent process.
rm -f /var/run/nginx.pid

# Set up the configuration and versions for canary release from docker environment variables
nginx-canary.sh

# Launch nginx
nginx -g "daemon off;"
