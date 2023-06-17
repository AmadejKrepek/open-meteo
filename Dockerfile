# ================================
# Build image contains swift compiler and libraries like netcdf or eccodes
# ================================
FROM ghcr.io/open-meteo/docker-container-build:latest as build
WORKDIR /build

# First just resolve dependencies.
# This creates a cached layer that can be reused
# as long as your Package.swift/Package.resolved
# files do not change.
COPY ./Package.* ./
RUN swift package resolve

# Copy entire repo into container
COPY . .

# Compile with optimizations
RUN swift build -c release


# ================================
# Run image contains swift runtime libraries, netcdf, eccodes, cdo and cds utilities
# ================================
FROM ghcr.io/open-meteo/docker-container-run:latest

# Create a openmeteo user and group with /app as its home directory
RUN useradd --user-group --create-home --system --skel /dev/null --home-dir /app openmeteo

#Install Cron
RUN apt-get update
RUN apt-get -y install cron

# Switch to the new home directory
WORKDIR /app

# Copy build artifacts
COPY --from=build --chown=openmeteo:openmeteo /build/.build/release/openmeteo-api /app
RUN mkdir -p /app/Resources
# COPY --from=build --chown=openmeteo:openmeteo /build/Resources /app/Resources
COPY --from=build --chown=openmeteo:openmeteo /build/.build/release/SwiftTimeZoneLookup_SwiftTimeZoneLookup.resources /app/Resources/
COPY --from=build --chown=openmeteo:openmeteo /build/Public /app/Public

# Attach a volumne
RUN mkdir /app/data && chown openmeteo:openmeteo /app/data
VOLUME /app/data

# Create a log directory and set it as a volume
RUN mkdir -p /app/logs && chown openmeteo:openmeteo /app/logs
VOLUME /app/logs

# Ensure all further commands run as the openmeteo user
USER openmeteo:openmeteo

# Start the service when the image is run, default to listening on 8080 in production environment 
ENTRYPOINT ["./openmeteo-api"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]

# Add the cron jobs
RUN crontab -l | { cat; echo "37 2,8,14,20  * * * if [ ! -f /app/logs/icon.log ]; then touch /app/logs/icon.log; fi && ./openmeteo-api download icon --only-variables temperature_2m,relativehumidity_2m,precipitation,snowfall_height,snow_depth,weathercode,pressure_msl,cloudcover,windgusts_10m > /app/logs/icon.log 2>&1 || cat /app/logs/icon.log"; } | crontab -
RUN crontab -l | { cat; echo "36 2,5,8,11,14,17,20,23  * * * if [ ! -f /app/logs/icon-eu.log ]; then touch /app/logs/icon-eu.log; fi && ./openmeteo-api download icon-eu --only-variables temperature_2m,relativehumidity_2m,precipitation,snowfall_height,snow_depth,weathercode,pressure_msl,cloudcover,windgusts_10m > /app/logs/icon-eu.log 2>&1 || cat /app/logs/icon-eu.log"; } | crontab -
RUN crontab -l | { cat; echo "44 0,3,6,9,12,15,18,21 * * * if [ ! -f /app/logs/icon-d2.log ]; then touch /app/logs/icon-d2.log; fi && ./openmeteo-api download icon-d2 --only-variables temperature_2m,relativehumidity_2m,precipitation,snowfall_height,snow_depth,weathercode,pressure_msl,cloudcover,windgusts_10m > /app/logs/icon-d2.log 2>&1 || cat /app/logs/icon-d2.log"; } | crontab -
# Uncomment and adjust the following lines if you have additional cron jobs
#RUN crontab -l | { cat; echo "45  7,19 * * * if [ ! -f /app/logs/ecmwf.log ]; then touch /app/logs/ecmwf.log; fi && ./openmeteo-api download-ecmwf > /app/logs/ecmwf.log 2>&1 || cat /app/logs/ecmwf.log"; } | crontab -
#RUN crontab -l | { cat; echo "0   1,13 * * * if [ ! -f /app/logs/ecmwf.log ]; then touch /app/logs/ecmwf.log; fi && ./openmeteo-api download-ecmwf > /app/logs/ecmwf.log 2>&1 || cat /app/logs/ecmwf.log"; } | crontab -

# Run the cron service on container startup
CMD cron