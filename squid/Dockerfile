FROM ubuntu:latest

# Setup proper timezone
ENV TZ="Europe/Warsaw"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install packages
RUN apt-get update && apt-get install squid tzdata -yq

# Copy and setup entrypoint to start Squid proxy
COPY entrypoint.sh .
RUN chmod +x ./entrypoint.sh

# Copy Squid personalized configuration file
COPY config/squid.conf /etc/squid/squid.conf

# Expose Squid TCP port
EXPOSE 3128/tcp

# Start Squid proxy
ENTRYPOINT ["./entrypoint.sh"]
