stepflow
========

An OTP application that implements Flume patterns.

Build
-----

    $ rebar3 compile

Run demo
--------

    $ rebar3 auto --sname pippo --apps stepflow --config priv/example.config
    1> gen_server:call(whereis(stepflow_agent), {append, hello}).
