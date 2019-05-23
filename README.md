# Hadoop 2.9.2-HA Docker image
基于Hadoop2.9.2版本，使用docker搭建高可用集群，高可用包含hdfs namenode HA，yarn HA

## 使用说明

Hadoop高可用集群依赖于Zookeeper，此镜像中不包含zookeeper，因此需要单独提供zookeeper服务。
要运行hadoop-ha集群，有两种方式可选：直接从docker hub拉取相关镜像并启动容器，或者自行构建。

### 1. 从DockerHub拉取镜像

```
docker pull okdokey/zookeeper:3.4.14
docker pull okdokey/hadoop:2.9.2-HA
```

#### 使用docker-compose命令启动服务集群

命令：
```
docker-compose -f docker-compose.yml up     #初次启动容器集群
docker-compose -f docker-compose.yml start  #启动容器服务集群
docker-compose -f docker-compose.yml stop   #关闭容器服务集群
```

编写docker-compoose.yml文件，内容参考如下：

```yaml
version: "2"
services:
    hadoop1:
        image: okdokey/hadoop:2.9.2-HA
        container_name: hadoop-nn1-rm1
        hostname: hadoop-nn1-rm1
        depends_on:
            - zk1
            - zk2
            - zk3
        networks:
            hadoop:
                aliases:
                    - master
                    - nn1
                    - rm1
        environment:
            ZK_SERVERS: zk1:2181,zk2:2181,zk3:2181
            HADOOP_WORKER_NAMES: hadoop1 hadoop2 hadoop3
            HDFS_JOURNAL_NODES: hadoop1:8485,hadoop2:8485,hadoop3:8485
        ports:
            - "8020:8020"
            - "8030:8030"
            - "8031:8031"
            - "8032:8032"
            - "8033:8033"
            - "8042:8042"
            - "8044:8044"
            - "8045:8045"
            - "8046:8046"
            - "8047:8047"
            - "8048:8048"
            - "8049:8049"
            - "8088:8088"
            - "8089:8089"
            - "8090:8090"
            - "8091:8091"
            - "8188:8188"
            - "8190:8190"
            - "8480:8480"
            - "8481:8481"
            - "8485:8485"
            - "8788:8788"
            - "10200:10200"
            - "50010:50010"
            - "50020:50020"
            - "50070:50070"
            - "50075:50075"
            - "10020:10020"
            - "19888:19888"
            - "19890:19890"
            - "10033:10033"
        command: [ "-m", "-d" ]
        
    hadoop2: 
        image: okdokey/hadoop:2.9.2-HA
        container_name: hadoop-nn2-rm2
        hostname: hadoop-nn2-rm2
        depends_on:
            - zk1
            - zk2
            - zk3
        networks:
            hadoop:
                aliases:
                    - standby
                    - nn2
                    - rm2
        environment:
            ZK_SERVERS: zk1:2181,zk2:2181,zk3:2181
            HADOOP_WORKER_NAMES: hadoop1 hadoop2 hadoop3
            HDFS_JOURNAL_NODES: hadoop1:8485,hadoop2:8485,hadoop3:8485
        ports:
            - "9088:8088"
            - "50071:50070"
        command: [ "-d" ]
        
    hadoop3: 
        image: okdokey/hadoop:2.9.2-HA
        container_name: hadoop-slave1
        hostname: hadoop-slave1
        depends_on:
            - zk1
            - zk2
            - zk3
        networks:
            hadoop:
                aliases:
                    - slave1
        environment:
            ZK_SERVERS: zk1:2181,zk2:2181,zk3:2181
            HADOOP_WORKER_NAMES: hadoop1 hadoop2 hadoop3
            HDFS_JOURNAL_NODES: hadoop1:8485,hadoop2:8485,hadoop3:8485 
        command: [ "-d" ]

    zk1:
        image: okdokey/zookeeper:3.4.14
        container_name: zk1
        hostname: zk1
        networks:
            hadoop:
                aliases:
                  - zk1
        ports:
            - 2181:2181
        environment:
            ZOO_MY_ID: 1
            ZOO_SERVERS: server.1=zk1:2888:3888 server.2=zk2:2888:3888 server.3=zk3:2888:3888

    zk2:
        image: okdokey/zookeeper:3.4.14
        container_name: zk2
        hostname: zk2
        networks:
            hadoop:
                aliases:
                  - zk2
        ports:
            - 2182:2181
        expose:
            - 2181
        environment:
            ZOO_MY_ID: 2
            ZOO_SERVERS: server.1=zk1:2888:3888 server.2=zk2:2888:3888 server.3=zk3:2888:3888

    zk3:
        image: okdokey/zookeeper:3.4.14
        container_name: zk3
        hostname: zk3
        networks:
            hadoop:
                aliases:
                  - zk3
        ports:
            - 2183:2181
        expose:
            - 2181
        environment:
            ZOO_MY_ID: 3
            ZOO_SERVERS: server.1=zk1:2888:3888 server.2=zk2:2888:3888 server.3=zk3:2888:3888
networks: 
    hadoop:
```
## 2. 自行构建镜像

你可以选择直接从Dockerfile构建，构建目录在docker-build，命令如下：

```
docker build -t hadoop:2.9.2-HA docker-build/
```

或者直接使用根目录下的docker-compose.yml文件进行构建和启动容器集群，
使用docker-compose可以直接构建镜像，并启动服务集群，只需要一条简单的命令：

```
docker-compose up
```

正常情况这样hadoop高可用集群就启动成功了，访问localhost:8088可以查看yarn集群状态，localhost:50070可以查看dfs状态
