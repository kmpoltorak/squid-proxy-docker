FROM ubuntu:latest

# Setup proper timezone
ENV TZ="Europe/Warsaw"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install packages (non-interactive), clean apt cache
RUN apt-get update \
	&& DEBIAN_FRONTEND=noninteractive apt-get install -yq squid tzdata \
	&& rm -rf /var/lib/apt/lists/*

# Copy and install entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy Squid personalized configuration file
COPY config/squid.conf /etc/squid/squid.conf

# Expose Squid TCP port
EXPOSE 3128/tcp

# Start Squid proxy via entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
