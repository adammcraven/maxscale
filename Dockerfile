FROM debian:jessie

MAINTAINER Adam Craven <adam@ChannelAdam.com>

ENV DEBIAN_FRONTEND noninteractive

# MaxScale downloads are listed here: https://mariadb.com/my_portal/download/maxscale
# apt-get update && apt-get install -y wget && \
RUN wget https://downloads.mariadb.com/enterprise/wm8m-g6r5/mariadb-maxscale/1.2.1/debian/dists/jessie/main/binary-amd64/maxscale-1.2.1-1.deb_jessie.x86_64.deb && \
    dpkg -i maxscale-1.2.1-1.deb_jessie.x86_64.deb

RUN apt-get update && apt-get install -y maxscale && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# VOLUME for custom configuration
VOLUME ["/etc/maxscale.d"]

# EXPOSE the MaxScale default ports
## RW Split Listener
#EXPOSE 4006
## Read Connection Listener
#EXPOSE 4008
## Debug Listener
#EXPOSE 4442 
## CLI Listener
#EXPOSE 6603 
# Custom port
EXPOSE 3306

COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD [""]