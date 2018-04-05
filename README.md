# Beehive-Routing
The routing engine of project Beehive.

## Installation

**Note:** Only continue if you are sure that you want to run the routing engine separately.
If you want to start the entire application consider [these](https://github.com/beehive-spg/beehive) instructions as they include all system components.

The routing engine depends on the database used in the Beehive project.
For details on how to build the docker image of the database simply look at the [beehive-database repository](https://github.com/beehive-spg/beehive-database).

After having successfully built the docker image for the database you can continue and simply startup the routing engine using:

```
docker-compose up
```

This will automatically download all images required to start and work with the routing engine.

For interacting with the application simply attach to the container.
You are automatically provided Elixir's interactive shell.
From there you have access to the entire application.

## Building your own Docker image

If you have made changes yourself and try them out, simply build the container from source:

```
docker build -t langhaarzombie/beehive-routing
```

The tag is important as it is used a identifier by the docker-compose file.
If you want to change the tag you need to adapt the docker-compose.yml accordingly.

## Interacting with the Routing Engine

### RabbitMQ

#### Connect to RabbitMQ

The RabbitMQ container exposes ports 5672 and 15672.
The former one being used as the amqp endpoint and the latter for the web interface.
In order to connect simply open `localhost:15672` in your browser.

#### Working with RabbitMQ

Queues of relevance are *new_orders* and *distribution*.
Both of them accept JSONs as message input.

JSON for *new_orders*:

```
{"from": "<shop_id>", "to": "<customer_id>"}
```

JSON for *distribution*:
```
{"from": "<building_id_hive>", "to": "<building_id_hive>"}
```

**Note:** When queueing a message for distribution it is required that the buildings are reachable.
In order to make sure that they are call `/api/reachable/{building1}/{building2}` using the database's web interface.

### Redis

#### Connect to Redis

It is not advised to interfere with Redis' processes,
but if you really want to have a look at it you can connect using the [redis-cli](https://redis.io/download) and the url `localhost:6379`.

#### Working with Redis

The most important instances stored in the redis database are the `active_jobs` list and each individual `arrival` and `departure`.
In order to retrieve active ids simply run `lrange active_jobs 0 -1`.
This will return all valid job ids that hold relevant data.

For getting details about an individual job (`arrival` or `departure`) simply take one of the ids retrieved above and run `hgetall <id>`.
This will give you details about the corresponding route and hop as well as the time the event is happening
(`departure` instances also include a reference to their corresponding `arrival` event).

In case ongoing routes should be deleted and instantly aborted, you can run `flushall`.
This will reset the Redis database.
Use this with caution.

### Database

#### Connect to Database

The database offers a great web interface to call certain routes and generally interact with the simulation.
By opening the url `localhost:4321` you can see the entire documentation and all routes that are available to you.

**Note:** When starting the routing engine as a single instance, you are required to add drones to each drone port or else no routes are possible to be processed.
This is done calling the REST route `/api/givedrones/{amount}` of the database.
See the web interface for details.

## License
Beehive-routing-buffer is released under the Apache License 2.0. See the license file _LICENSE_ for further information.
