#!/bin/bash

nohup redis-server \
  --port 6379 \
  --cluster-enabled yes \
  --cluster-config-file /var/lib/redis/nodes.conf \
  --cluster-node-timeout 5000 \
  --cluster-announce-ip $(hostname -i) \
  --cluster-announce-port 6379 \
  --cluster-announce-bus-port 16379 \
  --appendonly yes \
  --protected-mode no \
  --bind 0.0.0.0 \
  > /tmp/redis.log 2>&1 &

exec /usr/sbin/sshd -D
