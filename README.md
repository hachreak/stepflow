stepflow
========

An OTP application that implements Flume patterns.

Build
-----

    $ rebar3 compile

Run demo
--------

    $ rebar3 auto --sname pippo --apps stepflow --config priv/example.config

    1> SrcCtx = {[{stepflow_interceptor_counter, {}}], #{}}.
    2> Input = {stepflow_source_message, SrcCtx}.
    3> {ok, SkCtx1} = stepflow_sink:config(stepflow_sink_echo, nope).
    4> ChCtx1 = {stepflow_channel_memory, #{}, SkCtx1}.
    5> Output = [ChCtx1].
    6> {PidSub, PidS, PidCs} = stepflow_agent_sup:new(Input, Output).

    7> stepflow_source_message:append(PidS, <<"hello">>).

    8> SrcCtx2 = {[{stepflow_interceptor_counter, {}}], #{}}.
    9> Input2 = {stepflow_source_message, SrcCtx2}.
    10> {ok, SkCtx3} = stepflow_sink:config(stepflow_sink_message, PidS).
    11> ChCtx2 = {stepflow_channel_memory, #{}, SkCtx3}.
    12> Output2 = [ChCtx2].
    13> {PidSub2, PidS2, PidCs2} = stepflow_agent_sup:new(Input2, Output2).

    14> stepflow_source_message:append(PidS2, <<"hello">>).

