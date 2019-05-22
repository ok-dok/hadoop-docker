FROM openjdk:8-jre

# Setup sources
COPY sources.list /etc/apt/
RUN apt-get update

# Install dependencies
RUN apt-get -y install apt-utils; \
    apt-get -y install libsnappy1v5; \
    rm -rf /var/lib/apt/lists/*

# Grab gosu for easy step-down from root
ENV GOSU_VERSION 1.11
RUN set -ex; \
  wget -nv -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)"; \
  wget -nv -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc";
RUN export GNUPGHOME="$(mktemp -d)"; \
  for server in ha.pool.sks-keyservers.net \
                hkp://p80.pool.sks-keyservers.net:80 \
                keyserver.ubuntu.com \
                hkp://keyserver.ubuntu.com:80 \
                pgp.mit.edu ; do \
      gpg --batch --keyserver "$server" --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && break || : ; \
  done && \
  gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
  gpgconf --kill all; \
  rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc; \
  chmod +x /usr/local/bin/gosu; \
  gosu nobody true

# Install sshd
RUN apt-get update; \
    apt-get -y install openssh-server openssh-client 

# passwordless ssh
RUN ssh-keygen -q -N "" -t dsa -f /etc/ssh/ssh_host_dsa_key; \
    echo y | ssh-keygen -q -N "" -t rsa -f /etc/ssh/ssh_host_rsa_key; \
    ssh-keygen -q -N "" -t rsa -f /root/.ssh/id_rsa; \
    cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys; \
    chmod -R 700 /root/.ssh; \
    echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config;

# Configure Hadoop version
ENV HADOOP_VERSION 2.9.2

# Prepare environment
COPY hadoop_profile.sh /etc/profile.d/

RUN . /etc/profile

ENV HADOOP_HOME=/opt/hadoop \
    HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop 

# Add hadoop group and user
RUN groupadd --system --gid=9999 hadoop && \
    useradd --system -m --uid=9998 --gid=hadoop -s /bin/bash -c "Hadoop Account" hadoop

ENV HADOOP_FILE_URL http://mirrors.tuna.tsinghua.edu.cn/apache/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz
ENV HADOOP_ASC_URL https://www.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz.asc
ENV HADOOP_KEYS_URL https://www.apache.org/dist/hadoop/common/KEYS

WORKDIR ${HADOOP_HOME}
# Download Hadoop and verify
RUN set -ex; \
    wget -nv -O hadoop.tar.gz "$HADOOP_FILE_URL"; \
    wget -nv -O hadoop.tar.gz.asc "$HADOOP_ASC_URL"; \
    wget -nv -O KEYS "$HADOOP_KEYS_URL"; \
    gpg --import KEYS; \
    gpg --verify hadoop.tar.gz.asc hadoop.tar.gz; \
    rm -rf KEYS hadoop.tar.gz.asc; 

# COPY  hadoop.tar.gz ./

RUN tar -zxf hadoop.tar.gz --strip-components=1; \
    rm hadoop.tar.gz; \
    chown -R hadoop:hadoop .; 

# Copy configuration files
COPY core-site.xml  ${HADOOP_CONF_DIR}/
COPY hdfs-site.xml  ${HADOOP_CONF_DIR}/
COPY yarn-site.xml  ${HADOOP_CONF_DIR}/ 
COPY mapred-site.xml ${HADOOP_CONF_DIR}/

# Set JAVA_HOME environment
RUN echo JAVA_HOME=/docker-java-home/jre >> ${HADOOP_CONF_DIR}/hadoop-env.sh; \
  echo JAVA_HOME=/docker-java-home/jre >> ${HADOOP_CONF_DIR}/yarn-env.sh

# Generate ssh rsa key
WORKDIR /home/hadoop
RUN mkdir -p tmp hdfs/name hdfs/data .ssh; \
    ssh-keygen -q -N "" -t rsa -f .ssh/id_rsa; \
    cp .ssh/id_rsa.pub .ssh/authorized_keys; \
    chown -R hadoop:hadoop .; \
    chmod -R 700 .ssh;

COPY --chown=root:root bootstrap.sh /
COPY --chown=root:root start-dfs-cluster.sh /
COPY --chown=root:root start-yarn-cluster.sh /
RUN chmod 755 /start-dfs-cluster.sh; \
  chmod 755 /start-yarn-cluster.sh
  
# Configure container
COPY --chown=root:root docker-entrypoint.sh /
RUN chmod 755 /docker-entrypoint.sh
# SSH port
EXPOSE 22 
# HDFS ports
EXPOSE 50010 50020 50070 50075 50090 50470 50475 8485 8480 8481 8020
# MR ports
EXPOSE 10020 19888 19890 10033
# YARN ports
EXPOSE 8030 8031 8032 8033 8040 8042 8044 8045 8046 8047 8048 8049 8088 8089 8090 8091 8188 8190 10200 8788
ENTRYPOINT [ "/docker-entrypoint.sh" ]
CMD [ "/bin/bash" ]