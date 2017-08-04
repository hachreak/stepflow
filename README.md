stepflow
========

[![Build Status](https://travis-ci.org/hachreak/stepflow.svg?branch=master)](https://travis-ci.org/hachreak/stepflow)

An OTP application that implements Flume patterns.

It can be useful if you need to collect, aggregate, transform, move large
amount of data from/to different sources/destinations.

Implements ingest and real-time processing pipelines.

You can define `agents` that will forms a pipeline for events.
A event will represent a unit of information.
Every `agent` if made by one source and one or more sinks.

A source-sink is connected by a `channel`.
After a `source` and before every `sink` you can inject interceptors as many as
you want.
Every `interceptor` can enrich, transforms, aggregates, reject, ...

There are different channels: on RAM, on mnesia table, on RabbitMQ.

Every channels is made to take advantages of the technology used and
maximize the reliability of the system also if something goes wrong, depending
how much the memory is permanent.

All the events are staged inside the channel until they are successfully stored
inside the next agent or in a terminal repository (e.g. database, file, ...).

Build
-----

    $ rebar3 compile

Run demo 1
----------

Two agents connected:

```
  +-----------------------------+        +-----------------------------+
  |         Agent 1             |        |            Agent 2          |
  |                             |        |                             |
  |Source <--> Channel <--> Sink| <----> |Source <--> Channel <--> Sink|
  |                             |        |                             |
  +-----------------------------+        +-----------------------------+
```

    $ rebar3 auto --sname pippo --apps stepflow --config priv/example.config

    # Run Agent 1 and Agent 2

    1> [{_, {_, PidS1, _}}, {_, {_, PidS2, _}}] = stepflow_config:run("
          interceptor Counter = stepflow_interceptor_counter#{}.
          source FromMsg = stepflow_source_message[Counter]#{}.
          channel Memory = stepflow_channel_memory#{}.
          sink Echo = stepflow_sink_echo[Counter]#{}.

          flow Agent2: FromMsg |> Memory |> Echo.

          sink Connector = stepflow_sink_message[Counter]#{source => Agent2}.

          flow Agent1: FromMsg |> Memory |> Connector.
    ").

    # Send a message from Agent 1 to Agent 2
    2> stepflow_source_message:append(
        PidS1, [stepflow_event:new(#{}, <<"hello">>)]).

Run demo 2
----------

One source and two sinks (passing from memory and rabbitmq):

```
  +-------------------------------------------+
  |         Agent 1                           |
  |                                           |
  |Source <--> Channel1 (memory)   <--> Sink1 |
  |        |                                  |
  |        +-> Channel2 (rabbitmq) <--> Sink2 |
  +-------------------------------------------+
```

    $ rebar3 auto --sname pippo --apps stepflow --config priv/example.config

    1> [{_, {_, PidS, _}}] = stepflow_config:run("
        <<<
          FilterFun = fun(Events) ->
            lists:any(fun(E) -> E == <<\"filtered\">> end, Events)
          end.
        >>>

        interceptor Filter = stepflow_interceptor_filter#{filter => FilterFun}.
        interceptor Echo = stepflow_interceptor_echo#{}.
        source FromMsg = stepflow_source_message[]#{}.
        channel Memory = stepflow_channel_memory#{}.
        channel Rabbitmq = stepflow_channel_rabbitmq#{}.
        sink EchoMemory = stepflow_sink_echo[Echo]#{}.
        sink EchoRabbitmq = stepflow_sink_echo[Filter]#{}.

        flow Agent: FromMsg |> Memory   |> EchoMemory;
                            |> Rabbitmq |> EchoRabbitmq.
        ").

    > stepflow_source_message:append(PidS, [<<"hello">>]).
    > % filtered message!
    > stepflow_source_message:append(PidS, [<<"filtered">>]).

Run demo 3
----------

Count events but skip body `<<"found">>`:

    1> [{_, {_, PidS, _}}] = stepflow_config:run("
        <<<
        FilterFun = fun(Events) ->
            lists:any(fun(Event) ->
                stepflow_event:body(Event) == <<\"found\">>
              end, Events)
          end.
        >>>

        interceptor Counter = stepflow_interceptor_counter#{
          header => mycounter, eval => FilterFun
        }.
        interceptor Show = stepflow_interceptor_echo#{}.
        source FromMsg = stepflow_source_message[]#{}.
        channel Rabbitmq = stepflow_channel_rabbitmq#{}.
        sink Echo = stepflow_sink_echo[Counter, Show]#{}.

        flow Agent: FromMsg |> Rabbitmq |> Echo.
        ").

    # One event that is counted
    stepflow_source_message:append(PidS, [stepflow_event:new(#{}, <<"hello">>)]).

    # One event that is NOT counted
    stepflow_source_message:append(PidS, [stepflow_event:new(#{}, <<"found">>)]).

Run demo 4
----------

Handle bulk of 7 events with a window of 10 seconds:

    1> [{_, {_, PidS, _}}] = stepflow_config:run("
        interceptor Counter = stepflow_interceptor_counter#{}.
        source FromMsg = stepflow_source_message[Counter]#{}.
        channel Buffer = stepflow_channel_mnesia#{
            flush_period => 10, capacity => 7, table => mytable
        }.
        sink Echo = stepflow_sink_echo[]#{}.
        flow Squeeze: FromMsg |> Buffer |> Echo.
    ").

    # send multiple message quickly to fill the buffer!
    # you will see that they arrive all together.<F11>
    7> stepflow_source_message:append(PidS, [stepflow_event:new(#{}, <<"hello">>)]).
    8> stepflow_source_message:append(PidS, [stepflow_event:new(#{}, <<"hello">>)]).
    9> stepflow_source_message:append(PidS, [stepflow_event:new(#{}, <<"hello">>)]).

Run demo 5
----------

Aggregate events in a single one:

    1> [{_, {_, PidS, _}}] = stepflow_config:run("
        <<<
        SqueezeFun = fun(Events) ->
                 BodyNew = lists:foldr(fun(Event, Acc) ->
                     Body = stepflow_event:body(Event),
                     << Body/binary, <<\" \">>/binary, Acc/binary >>
                   end, <<\"\">>, Events),
                 {ok, [stepflow_event:new(#{}, BodyNew)]}
               end.
        >>>

        interceptor Squeezer = stepflow_interceptor_transform#{
          eval => SqueezeFun
        }.
        source FromMsg = stepflow_source_message[Squeezer]#{}.
        channel Mnesia = stepflow_channel_mnesia#{
          flush_period => 10, capacity => 2, table => pippo
        }.
        sink Echo = stepflow_sink_echo[]#{}.

        flow Aggretator: FromMsg |> Mnesia |> Echo.
        ").

    8> stepflow_source_message:append(PidS, [
         stepflow_event:new(#{}, <<"hello">>),
         stepflow_event:new(#{}, <<" world">>)
       ]).

Run demo 6
----------

Index events in ElasticSearch.

```
          +------------------------------------------------------------------+
          |                              Agent 1                             |
User      |                                                                  |
 |        |     Source <---------------> Channel <--------> Sink             |
 +------->| (erlang message)             (memory)       (index inside ES)    |
   SEND   |                                                                  |
   Event  +------------------------------------------------------------------+
 <<"hello">>
```

    $ rebar3 shell --apps stepflow_sink_elasticsearch

    1> [{_, {_, PidS, _}}] = stepflow_config:run("
          interceptor Counter = stepflow_interceptor_counter#{}.
          source FromMsg = stepflow_source_message[Counter]#{}.
          channel Memory = stepflow_channel_memory#{}.
          sink Elasticsearch = stepflow_sink_elasticsearch[]#{
            host => <<\"localhost\">>, port => 9200, index => <<\"myindex\">>
          }.

          flow Agent: FromMsg |> Memory |> Elasticsearch.
       ").

    2> stepflow_source_message:append(
          PidS, [stepflow_event:new(#{}, <<"hello">>)]).


Note
----

You can run `RabbitMQ` with docker:

    $ docker run --rm --hostname my-rabbit --name some-rabbit -p 5672:5672 -p 15672:15672 rabbitmq:3-management

And open the web interface:

    $ firefox http://0.0.0.0:15672/#/

You can run `ElasticSearch` with docker:

    $ docker pull docker.elastic.co/elasticsearch/elasticsearch:5.5.0
    $ docker run -p 9200:9200 -e "http.host=0.0.0.0" -e "transport.host=127.0.0.1" -e "xpack.security.enabled=false" docker.elastic.co/elasticsearch/elasticsearch:5.5.0

Status
------

The module is still quite unstable because the heavy development.
The API could change until at least v0.1.0.
