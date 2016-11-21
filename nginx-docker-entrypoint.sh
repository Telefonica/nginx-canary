#!/bin/sh -e

# Set up the configuration and versions for canary release from docker environment variables
nginx-canary.sh

# Launch nginx
nginx -g "daemon off;"
