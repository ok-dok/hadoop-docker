# Hadoop 3.2.0 Docker image
基于Hadoop3.2.0版本，使用docker搭建高可用集群，高可用包含hdfs namenode HA，yarn HA
# 构建镜像
```
docker build -t hadoop:HA docker-build/
```
# 启动镜像
```
docker-compose up
```
待集群启动后，要在另一台namenode上执行bootstrapStandby
```
docker exec -it hadoop-nn2-rm2 /bootstrap.sh -b
```
这样hadoop高可用集群就启动成功了，访问localhost:8088可以查看yarn集群状态，localhost:9870可以查看dfs状态
