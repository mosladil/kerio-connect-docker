#
# Kerio Connect Dockerfile
#
# https://github.com/mosladil/kerio-connect-docker

# Use the Ubuntu LTS with Kerio Connect
FROM ubuntu:latest
MAINTAINER Miroslav Osladil <mosladil@kerio.com>

# Kerio Connect
ENV CONNECT_NAME kerio-connect
ENV CONNECT_VERSION 8.5.0
ENV CONNECT_BUILD 4416
ENV CONNECT_BETA false
ENV CONNECT_HOME /opt/kerio/mailserver

# Container content
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD http://cdn.kerio.com/dwn/connect/connect-${CONNECT_VERSION}-${CONNECT_BUILD}/kerio-connect-${CONNECT_VERSION}-${CONNECT_BUILD}-linux-amd64.deb /tmp/kerio-connect-${CONNECT_VERSION}-${CONNECT_BUILD}-linux-amd64.deb

# Install and setup project dependencies
RUN echo root:kerio | chpasswd
RUN DEBIAN_FRONTEND=noninteractive apt-get -qqy update && apt-get -qqy install curl lsof supervisor sysstat && apt-get clean
RUN locale-gen en_US en_US.UTF-8
RUN dpkg -i /tmp/kerio-connect-${CONNECT_VERSION}-${CONNECT_BUILD}-linux-amd64.deb && rm /tmp/kerio-connect-${CONNECT_VERSION}-${CONNECT_BUILD}-linux-amd64.deb
RUN ln -s ${CONNECT_HOME}/sendmail /usr/sbin/sendmail

# Store hacks
RUN mkdir -p \
	/data/dbSSL \
	/data/license \
	/data/settings \
	/data/sslcert \
	/data/store
RUN touch \
	/data/charts.dat \
	/data/cluster.cfg \
	/data/mailserver.cfg \
	/data/stats.dat \
	/data/users.cfg
RUN rm -rf ${CONNECT_HOME}/license
RUN ln -s /data/charts.dat ${CONNECT_HOME} &&\
	ln -s /data/cluster.cfg ${CONNECT_HOME} &&\
	ln -s /data/dbSSL ${CONNECT_HOME} &&\
	ln -s /data/license ${CONNECT_HOME} &&\
	ln -s /data/mailserver.cfg ${CONNECT_HOME} &&\
	ln -s /data/settings ${CONNECT_HOME} &&\
	ln -s /data/sslcert ${CONNECT_HOME} &&\
	ln -s /data/stats.dat ${CONNECT_HOME} &&\
	ln -s /data/store ${CONNECT_HOME} &&\
	ln -s /data/users.cfg ${CONNECT_HOME}
RUN rm -rf /data

# Define mountable directories.
VOLUME ["/data", "/opt/kerio/mailserver/store"]

# Export ports
EXPOSE 25 465 587 110 995 143 993 119 563 389 636 80 443 2000 4040 5222 5223 8800 8843

# Start container
CMD ["/usr/bin/supervisord"]
