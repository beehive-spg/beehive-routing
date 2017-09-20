# Beehive-Routing-Buffer
A buffer for the routing engine to store commands.

## Before starting
Make sure that there is a redis server available.

### Create custom redis server
In order to quick test this module just create a Docker container:
```
docker run --name beehive-redis -it -p 6379:6379 redis
```
Note: This creates a permanent copy of the container with the name _beehive-redis_ on your machine. In order to remove it again use:
```
docker rm beehive-redis.
```

### Use existing redis server
If there is also a redis server running (that is not operating on localhost:6379) you just need to edit the settings in config/config.exs

## License
Beehive-routing-buffer is released under the Apache License 2.0. See the license file _LICENSE_ for further information.