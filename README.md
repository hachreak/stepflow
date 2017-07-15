stepflow
========

An OTP application that implements Flume patterns.

Build
-----

    $ rebar3 compile

Run demo 1
----------

    $ rebar3 auto --sname pippo --apps stepflow --config priv/example.config

    1> SrcCtx = {[{stepflow_interceptor_counter, {}}], #{}}.
    2> Input = {stepflow_source_message, SrcCtx}.
    3> {ok, SkCtx1} = stepflow_sink:config(stepflow_sink_echo, nope, [{stepflow_interceptor_counter, {}}]).
    4> ChCtx1 = {stepflow_channel_memory, #{}, SkCtx1}.
    5> Output = [ChCtx1].
    6> {PidSub, PidS, PidCs} = stepflow_agent_sup:new(Input, Output).

    7> stepflow_source_message:append(PidS, <<"hello">>).

    8> SrcCtx2 = {[{stepflow_interceptor_counter, {}}], #{}}.
    9> Input2 = {stepflow_source_message, SrcCtx2}.
    10> {ok, SkCtx3} = stepflow_sink:config(stepflow_sink_message, #{source => PidS}, [{stepflow_interceptor_counter, {}}]).
    11> ChCtx2 = {stepflow_channel_memory, #{}, SkCtx3}.
    12> Output2 = [ChCtx2].
    13> {PidSub2, PidS2, PidCs2} = stepflow_agent_sup:new(Input2, Output2).

    14> stepflow_source_message:append(PidS2, <<"hello">>).

Run demo 2
----------

    $ rebar3 auto --sname pippo --apps stepflow --config priv/example.config

    1> SrcCtx = {[{stepflow_interceptor_counter, {}}], #{}}.
    2> Input = {stepflow_source_message, SrcCtx}.
    3> {ok, SkCtx1} = stepflow_sink:config(stepflow_sink_echo, nope, [{stepflow_interceptor_echo, {}}]).
    4> {ok, SkCtx2} = stepflow_sink:config(stepflow_sink_echo, nope, []).
    5> ChCtx1 = {stepflow_channel_memory, #{}, SkCtx1}.
    6> ChCtx2 = {stepflow_channel_rabbitmq, #{}, SkCtx2}.
    7> Output = [ChCtx1, ChCtx2].
    8> {PidSub, PidS, PidC} = stepflow_agent_sup:new(Input, Output).

    9> stepflow_source_message:append(PidS, <<"hello">>).

Status
------

The module is still quite unstable because the heavy development.
The API could change until at least v0.1.0.
