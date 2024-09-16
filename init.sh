#!/bin/bash

# Start the cron service
service cron start

# Load cron job entries from the cronjobs.txt file
crontab /app/cronjobs

# Run the cron daemon in the foreground
cron -f &

# Execute the openmeteo-api script
./openmeteo-api serve --env production --hostname 0.0.0.0 --port 8080
