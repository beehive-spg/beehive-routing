@moduledoc """
A schema is a keyword list which represents how to map, transform, and validate
configuration values parsed from the .conf file. The following is an explanation of
each key in the schema definition in order of appearance, and how to use them.

## Import

A list of application names (as atoms), which represent apps to load modules from
which you can then reference in your schema definition. This is how you import your
own custom Validator/Transform modules, or general utility modules for use in
validator/transform functions in the schema. For example, if you have an application
`:foo` which contains a custom Transform module, you would add it to your schema like so:

`[ import: [:foo], ..., transforms: ["myapp.some.setting": MyApp.SomeTransform]]`

## Extends

A list of application names (as atoms), which contain schemas that you want to extend
with this schema. By extending a schema, you effectively re-use definitions in the
extended schema. You may also override definitions from the extended schema by redefining them
in the extending schema. You use `:extends` like so:

`[ extends: [:foo], ... ]`

## Mappings

Mappings define how to interpret settings in the .conf when they are translated to
runtime configuration. They also define how the .conf will be generated, things like
documention, @see references, example values, etc.

See the moduledoc for `Conform.Schema.Mapping` for more details.

## Transforms

Transforms are custom functions which are executed to build the value which will be
stored at the path defined by the key. Transforms have access to the current config
state via the `Conform.Conf` module, and can use that to build complex configuration
from a combination of other config values.

See the moduledoc for `Conform.Schema.Transform` for more details and examples.

## Validators

Validators are simple functions which take two arguments, the value to be validated,
and arguments provided to the validator (used only by custom validators). A validator
checks the value, and returns `:ok` if it is valid, `{:warn, message}` if it is valid,
but should be brought to the users attention, or `{:error, message}` if it is invalid.

See the moduledoc for `Conform.Schema.Validator` for more details and examples.
"""
[
  extends: [],
  import: [],
  mappings: [
    "logger.level": [
      commented: false,
      datatype: :atom,
      default: :debug,
      doc: "Provide documentation for logger.level here.",
      hidden: false,
      to: "logger.level"
    ],
    "logger.truncate": [
      commented: false,
      datatype: :integer,
      default: 4096,
      doc: "Provide documentation for logger.truncate here.",
      hidden: false,
      to: "logger.truncate"
    ],
    "logger.compile_time_purge_level": [
      commented: false,
      datatype: :atom,
      default: :debug,
      doc: "Provide documentation for logger.compile_time_purge_level here.",
      hidden: false,
      to: "logger.compile_time_purge_level"
    ],
    "logger.backends": [
      commented: false,
      datatype: [
        list: :atom
      ],
      default: [
        :console
      ],
      doc: "Provide documentation for logger.backends here.",
      hidden: false,
      to: "logger.backends"
    ],
    "redix.host": [
      commented: false,
      datatype: :binary,
      default: "localhost",
      doc: "Provide documentation for redix.host here.",
      hidden: false,
      to: "redix.host"
    ],
    "redix.port": [
      commented: false,
      datatype: :integer,
      default: 6379,
      doc: "Provide documentation for redix.port here.",
      hidden: false,
      to: "redix.port"
    ],
    "fromats.datetime": [
      commented: false,
      datatype: :binary,
      default: "{ISO:Extended}",
      doc: "Provide documentation for fromats.datetime here.",
      hidden: false,
      to: "fromats.datetime"
    ],
    "buffer.Elixir.Buffer.Secretary.overlap": [
      commented: false,
      datatype: :atom,
      default: false,
      doc: "Provide documentation for buffer.Elixir.Buffer.Secretary.overlap here.",
      hidden: false,
      to: "buffer.Elixir.Buffer.Secretary.overlap"
    ],
    "buffer.Elixir.Buffer.Secretary.timezone": [
      commented: false,
      datatype: :atom,
      default: :utc,
      doc: "Provide documentation for buffer.Elixir.Buffer.Secretary.timezone here.",
      hidden: false,
      to: "buffer.Elixir.Buffer.Secretary.timezone"
    ],
    "buffer.Elixir.Buffer.Secretary.jobs.check_for_job.schedule": [
      commented: false,
      datatype: {:atom, :binary},
      default: {:extended, "*/1"},
      doc: "Provide documentation for buffer.Elixir.Buffer.Secretary.jobs.check_for_job.schedule here.",
      hidden: false,
      to: "buffer.Elixir.Buffer.Secretary.jobs.check_for_job.schedule"
    ],
    "buffer.Elixir.Buffer.Secretary.jobs.check_for_job.task": [
      commented: false,
      datatype: {:atom, :atom, :binary},
      default: {Buffer.Secretary, :check, []},
      doc: "Provide documentation for buffer.Elixir.Buffer.Secretary.jobs.check_for_job.task here.",
      hidden: false,
      to: "buffer.Elixir.Buffer.Secretary.jobs.check_for_job.task"
    ]
  ],
  transforms: [],
  validators: []
]