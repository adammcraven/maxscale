FROM debian:jessie

MAINTAINER Adam Craven <adam@ChannelAdam.com>

ENV DEBIAN_FRONTEND noninteractive

# Pre-requisites for MaxScale
RUN apt-get update && \
    apt-get install -y apt-utils && \
    apt-get install -y libaio1 && \
    apt-get install -y libcurl3

# MaxScale downloads are listed here: https://mariadb.com/my_portal/download/maxscale
RUN apt-get update && apt-get install -y wget && \
    wget https://downloads.mariadb.com/enterprise/wm8m-g6r5/mariadb-maxscale/1.2.1/debian/dists/jessie/main/binary-amd64/maxscale-1.2.1-1.deb_jessie.x86_64.deb && \
    dpkg -i maxscale-1.2.1-1.deb_jessie.x86_64.deb

RUN apt-get update && apt-get install -y maxscale && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# VOLUME for log files
RUN mkdir /var/lib/maxscale/log
VOLUME ["/var/lib/maxscale/log"]


# EXPOSE ports
# Galera Splitter Listener
EXPOSE 3306
## CLI Listener
EXPOSE 6604


COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD [""]