stepflow
========

An OTP application that implements Flume patterns.

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

    # Run Agent 2

    1> SrcCtx = {[{stepflow_interceptor_counter, #{}}], #{}}.
    2> Input = {stepflow_source_message, SrcCtx}.
    3> {ok, SkCtx1} = stepflow_sink:config(stepflow_sink_echo, nope, [{stepflow_interceptor_counter, #{}}]).
    4> ChCtx1 = {stepflow_channel_memory, #{}, SkCtx1}.
    5> Output = [ChCtx1].
    6> {PidSub, PidS, PidCs} = stepflow_agent_sup:new(Input, Output).

    # Run Agent 1

    7> SrcCtx2 = {[{stepflow_interceptor_counter, #{}}], #{}}.
    8> Input2 = {stepflow_source_message, SrcCtx2}.
    9> {ok, SkCtx3} = stepflow_sink:config(stepflow_sink_message, #{source => PidS}, [{stepflow_interceptor_counter, #{}}]).
    10> ChCtx2 = {stepflow_channel_memory, #{}, SkCtx3}.
    11> Output2 = [ChCtx2].
    12> {PidSub2, PidS2, PidCs2} = stepflow_agent_sup:new(Input2, Output2).

    # Send a message from Agent 1 to Agent 2
    14> stepflow_source_message:append(PidS2, [stepflow_event:new(#{}, <<"hello">>)]).

Run demo 2
----------

One source and two sinks (passing from memory and rabbitmq):

    $ rebar3 auto --sname pippo --apps stepflow --config priv/example.config

    1> Filter = fun(Event) -> Event == <<"filtered">> end.
    2> SrcCtx = {[{stepflow_interceptor_filter, #{filter => Filter}}], #{}}.
    3> Input = {stepflow_source_message, SrcCtx}.
    4> {ok, SkCtx1} = stepflow_sink:config(stepflow_sink_echo, nope, [{stepflow_interceptor_echo, {}}]).
    5> {ok, SkCtx2} = stepflow_sink:config(stepflow_sink_echo, nope, []).
    6> ChCtx1 = {stepflow_channel_memory, #{}, SkCtx1}.
    7> ChCtx2 = {stepflow_channel_rabbitmq, #{}, SkCtx2}.
    8> Output = [ChCtx1, ChCtx2].
    9> {PidSub, PidS, PidC} = stepflow_agent_sup:new(Input, Output).

    > stepflow_source_message:append(PidS, [<<"hello">>]).
    > % filtered message!
    > stepflow_source_message:append(PidS, [<<"filtered">>]).

Run demo 3
----------

Count the events `<<"hello">>`:

    1> Filter = fun(#{body := Body}) -> Body =:= <<"hello">> end.
    2> SrcCtx = {[{stepflow_interceptor_counter, #{header => mycounter, eval => Filter}}, {stepflow_interceptor_echo, #{}}], #{}}.
    3> Input = {stepflow_source_message, SrcCtx}.
    4> {ok, SkCtx} = stepflow_sink:config(stepflow_sink_echo, nope, [{stepflow_interceptor_echo, {}}]).
    5> ChCtx = {stepflow_channel_rabbitmq, #{}, SkCtx}.
    6> Output = [ChCtx].
    7>{PidSub, PidS, PidC} = stepflow_agent_sup:new(Input, Output).

    # One event that is counted
    stepflow_source_message:append(PidS, [stepflow_event:new(#{}, <<"hello">>)]).

    # One event that is NOT counted
    stepflow_source_message:append(PidS, [stepflow_event:new(#{}, <<"skip">>)]).

Run demo 4
----------

Handle bulk of 7 events with a window of 10 seconds:

    1> SrcCtx = {[{stepflow_interceptor_counter, #{}}], #{}}.
    2> Input = {stepflow_source_message, SrcCtx}.
    3> {ok, SkCtx} = stepflow_sink:config(stepflow_sink_echo, #{}, []).
    4> ChCtx = {stepflow_channel_mnesia, #{flush_period => 10, capacity => 7, table => mytable}, SkCtx}.
    5> Output = [ChCtx].
    6> {PidSub, PidS, PidCs} = stepflow_agent_sup:new(Input, Output).

    # send multiple message quickly!
    7> stepflow_source_message:append(PidS, [stepflow_event:new(#{}, <<"hello">>)]).
    8> stepflow_source_message:append(PidS, [stepflow_event:new(#{}, <<"hello">>)]).
    9> stepflow_source_message:append(PidS, [stepflow_event:new(#{}, <<"hello">>)]).

Run demo 5
----------

Filter <<"hello">> events:

    1> Fun = fun(#{body := Body}=Event) -> case Body =:= <<"hello">> of false -> {ok, stepflow_event:header(check, true, Event)}; _ -> reject end end.
    2> SrcCtx = {[{stepflow_interceptor_transform, #{eval => Fun}}], #{}}.
    3> Input = {stepflow_source_message, SrcCtx}.
    4> {ok, SkCtx} = stepflow_sink:config(stepflow_sink_echo, #{}, []).
    5> ChCtx = {stepflow_channel_mnesia, #{flush_period => 10, capacity => 7, table => pippo}, SkCtx}.
    6> Output = [ChCtx].
    7> {PidSub, PidS, PidCs} = stepflow_agent_sup:new(Input, Output).

    8> stepflow_source_message:append(PidS, stepflow_event:new(#{}, <<"hello">>)).
    9> stepflow_source_message:append(PidS, stepflow_event:new(#{}, <<"this is passing">>)).

Note
----

You can run rabbitmq with docker:

    $ docker run --rm --hostname my-rabbit --name some-rabbit -p 5672:5672 -p 15672:15672 rabbitmq:3-management

And open the web interface:

    $ firefox http://0.0.0.0:15672/#/

Status
------

The module is still quite unstable because the heavy development.
The API could change until at least v0.1.0.
