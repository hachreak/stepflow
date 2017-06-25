stepflow
========

An OTP application that implements Flume patterns.

Build
-----

    $ rebar3 compile

Run demo 1
----------

    $ rebar3 auto --sname pippo --apps stepflow --config priv/example.config
    1> {ok, Flows} = application:get_env(stepflow, flows).
    2> FlowConfigs = stepflow_agent:config(Flows).
    3> {ok, Pid} = supervisor:start_child(whereis(stepflow_agent_sup), [FlowConfigs]).
    4> gen_server:call(Pid, {append, hello}).
    4> stepflow_agent:append(Pid, hello).

Run demo 2
----------

In this example, we have two agent connected and we'll try to send a message
through them.

    $ rebar3 auto --sname pippo --apps stepflow --config priv/example.config

    1> {ok, Flows} = application:get_env(stepflow, flows).
    2> FlowConfigs = stepflow_agent:config(Flows).
    3> {ok, Pid} = supervisor:start_child(whereis(stepflow_agent_sup), [FlowConfigs]).

    4> Flow2 = {[], {stepflow_channel_memory,nope}, {stepflow_sink_message, Pid}}.
    5> FlowConfigs2 = stepflow_agent:config([Flow2]).
    6> {ok, Pid2} = supervisor:start_child(whereis(stepflow_agent_sup), [FlowConfigs2]).
    7> stepflow_agent:append(Pid2, hello).
