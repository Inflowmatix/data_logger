# DataLogger

A logger that can be used to log any kind of data to remote or local destinations.

It is similar to the Elixir Logger, but doesn't log only binary data and is highly concurrent,
supporting logging to multiple destinations concurrently, even being able to log
to multiple sub-destinations of the same destination in the same time.

Can be used to send data to persistent queues, which can be then consumed by on-demand
consumers powered by `GenStage` if the Elixir producer doesn't work on demand.

Can be used to send data to data bases, transofrming it in the process.
Databases like Postgres, MySql, DynamoDB, MongoDB, etc.

Can be used as a replacement of the Elixir Logger too, if a smart wrapper around it is built.

Can be used to send data to pub-sub topics.

## Installation

The package can be installed by adding `data_logger` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:data_logger, "~> 0.3.2"}
  ]
end
```

Run `mix deps.get` to download it.

## Usage

A `DataLogger` can log any data to any configured destination.

A destination can be configured using the the application configuration:

    config :data_logger,
      destinations: [
        {DestinationImplementation, %{option_one: value_one, option_two: value_two}},
        {AnoterDestinationImplementation, %{option: value}}
      ]

When such a configuration is defined, chunks of data, represented by Elixir terms
can be logged to them by using the `DataLogger.log/2` function.

For example we could have two schemas in a relational database : *green* and *red*.
We would like to send a list of records to a destination representing this database.
When we have data that should go to the *green* schema, we would use:

    DataLogger.log(:green, [row1, row2, row3])

When we want data sent and stored to the *red* schema, we would use:

    DataLogger.log(:red, [row1, row2, row3, row4])

This way we could have different schemas or tables or clients, etc and send
data related to them to a storage defined for them.
In the *red* and *green* example the configuration would be:

    config :data_logger,
      destinations: [
        {RelationalDBDestination, %{host: "localhost", user: "inflowmatix", password: "secret"}}
      ]

The destination should be a module, which implements the `DataLogger.Destination` protocol.

For both the *green* and the *red* data there will be independent supervisor tree with a worker
per destination so the data sent to the *green* destination won't be in the way of the data sent
to the *red* destination.

By default the data logged by `DataLogger.log/2` is send in the worker process
for the given `topic` (*green* or *red*) in the above example.
This can be changed if in the options of the destination `:send_async` is set to `true`:

    config :data_logger,
      destinations: [
        {RelationalDBDestination, %{host: "localhost", user: "inflowmatix", password: "secret", send_async: true}}
      ]

Now every chunk of data logged with that `topic` will be send in its own supervised process.
The `DataLogger.Destination` behaviour implementation can define `on_error/4` or/and `on_success/4`
callbacks so the result can be handled.

Ensuring that the data has been sent and retrying sending it, if needed is a responsibility of the destination
implementation.

### Prefixes

From version `0.3.0` the DataLogger can have destinations with prefixes, like:

    destinations: [
      {MyDestination, %{prefix: "blue"}},
      {MyOtherDestination, %{prefix: "purple"}}
    ]

Now data logged with `DataLogger.log("purple_1", <data>)` will be sent only the `MyOtherDestination`.
Multiple destinations can have the same prefix.

## Documentation

Documentation can be found at [https://hexdocs.pm/data_logger](https://hexdocs.pm/data_logger).

