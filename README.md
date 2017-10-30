# Beehive-Routing-Buffer
A buffer for the routing engine to store commands.

## Before Starting
Make sure that there is a redis server available.

### Create Custom Redis Server
In order to quick test this module just create a Docker container:
```
docker run --name beehive-redis -it -p 6379:6379 redis
```
Note: This creates a permanent copy of the container with the name _beehive-redis_ on your machine. In order to remove it again use:
```
docker rm beehive-redis
```

### Use Existing Redis Server
If there is already a redis server running (that is not operating on localhost:6379) you just need to edit the settings in *config/config.exs*.

## Facts To Keep In Mind

### Adding & Removing Arrivals

Details of arrivals are stored as hashes in Redis. They conform the following structure:

```
arr_42, time: "2017-10-10 12:20:00", drone: "512", location: "15", is_delivery: "true"
```

The id *arr_42* changes based on the next number assigned. Every arrival as well as departure needs to be unique therefore the id is always incremented by one.

The time is stored in *ISO:Extended* and is converted for calculations internally.

The drone id is based on the drone that is assigned that action.

The location id is based on the location where the action is happening.

The field *is_delivery* indicated whether the action that is being performed is a delivery or a redistribution. This is important because depending on that different different parts of the system need to be notified.

### Adding & Removing Departures

The same what is true for arrivals also applies for departures except that their ids start with *dep_* instead of arr_.

However departures have an extra field that indicates the arrival they are corresponding to (a drone cannot just leave without ever landing). Therefore, the structure of a departure looks like so:

```
dep_41, time: "2017-10-10 12:11:00", drone: "512", location: "16", is_delivery: "true", arrival: "arr_42"
```

### Defining IDs

The next id to be taken for each arrival and departure is given by the fields *arr_next_id* and *dep_next_id*. Depending on their value they can be resetted after some time by logging into the system.

### Storing The Next Job To Be Done

Whenever an arrival or departure is added the list of currently active jobs is refreshed. The very next job to be done is always on the very left (because it is easy to use with [head | tail]). The list in which the ids are stored is named *active_jobs*.

### Adding Routes

Routes are a combination of departures and arrivals. Each pair of departure and arrival is called a hop which is performed by one drone and has a location as a start as well as end point. Locations do not have to be hives. If we for example think of dropping the packet at customers, they might not have a hive.

Routes in particular are not stored in the Redis DB. Only the events.

A route when processed in the system conforms the follwoing structure:

```
route = %{:is_delivery => true/false, :route => [%{:from => "16", to => "15", dep_time => "2017-10-10 12:11:00", arr_time => "2017-10-10 12:20:00", drone => "512"}, ...]}
```

### Time Based Job Execution

The system uses [Quantum](https://github.com/c-rack/quantum-elixir) in order to simulate time. Every second the Secretary looks for the next job in the *active_jobs* list. Depending on the type of job different commands are executed.

## License
Beehive-routing-buffer is released under the Apache License 2.0. See the license file _LICENSE_ for further information.
