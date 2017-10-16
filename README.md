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
docker rm beehive-redis
```

### Use existing redis server
If there is already a redis server running (that is not operating on localhost:6379) you just need to edit the settings in *config/config.exs*.

## Facts to keep in mind

### Adding and removing arrivals

Details of arrivals are stored as hashes in Redis. They conform the following structure:

```
arr_42, time: *2017-10-10 12:11:00*, drone: *512*, hive: *16*, is_delivery: *true*
```

The id *arr_42* changes based on the next number assigned. Every arrival as well as departure needs to be unique therefore the id is always incremented by one.

The time is stored in ISO:Extended and is converted for calculations internally.

The drone id is based on the drone that is assigned that action.

The hive id is based on the hive where the action is happening.

The field *is_delivery* indicated whether the action that is being performed is a delivery or a redistribution. This is important because depending on that different different parts of the system need to be notified.

### Adding and removing departures

The same what is true for arrivals also applies for departures except that their ids start with *dep_* instead of arr_.

### Defining ids

The next id to be taken for each arrival and departure is given by the fields *arr_next_id* and *dep_next_id*. Depending on their value they can be resetted after some time by logging into the system.

### Storing the next job to be done

Whenever an arrival or departure is added the list of currently active jobs is refreshed. The very next job to be done is always on the very left (because it is easy to use with [head | tail]). The list in which the ids are stored is named *active_jobs*.

## License
Beehive-routing-buffer is released under the Apache License 2.0. See the license file _LICENSE_ for further information.
