stepflow
========

An OTP application that implements Flume patterns.

Build
-----

    $ rebar3 compile

Run demo
--------

    $ rebar3 auto --sname pippo --apps stepflow --config priv/example.config
    1> {ok, Flows} = application:get_env(stepflow, flows).
    2> FlowConfigs = stepflow_agent:config(Flows).
    3> {ok, Pid} = supervisor:start_child(whereis(stepflow_agent_sup), [FlowConfigs]).
    4> gen_server:call(Pid, {append, hello}).
