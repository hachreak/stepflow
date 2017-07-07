%%%-------------------------------------------------------------------
%% @doc stepflow agent
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_agent).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(gen_server).

-export([
  append/2,
  config/1,
  start_link/1
]).

%% Callbacks
-export([
  attach/2,
  init/1,
  code_change/3,
  debug/2,
  detach/2,
  pop/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2
]).

-type chctx() :: stepflow_channel:chctx().
-type skctx() :: stepflow_sink:skctx().

%%====================================================================
%% API
%%====================================================================

start_link([{_Interceptors, _Channel, _Sink} | _]=FlowConfigs) ->
  gen_server:start_link(?MODULE, [FlowConfigs], []).

% @doc load agent configuration to pass to the agent when start.
% @end
-spec config(list()) -> list().
config(Flows) ->
  lists:map(fun({InterceptorsConfig, ChannelConfig, SinkConfig}) ->
      {config_interceptors(InterceptorsConfig),
       config_channel(ChannelConfig, config_sink(SinkConfig)),
       config_sink(SinkConfig)}
    end, Flows).

append(Pid, Event) ->
  gen_server:call(Pid, {append, Event}).

pop(Pid) ->
  gen_server:cast(Pid, pop).

attach(Pid, FlowConfig) ->
  gen_server:cast(Pid, {attach, FlowConfig}).

detach(Pid, SinkPid) ->
  gen_server:call(Pid, {detach, SinkPid}).

debug(Pid, flow) ->
  gen_server:call(Pid, {debug, flow}).

%% Callbacks

init([FlowConfigs]) ->
  process_flag(trap_exit, true),
  {ok, #{flows => FlowConfigs}}.

handle_call({append, Event}, _From, #{flows := FlowConfigs}=Ctx) ->
  Outputs2 = lists:map(fun({InterceptorsCtx, ChannelCtx, SinkCtx}) ->
      {InterceptorsCtx2, ChannelCtx2} = append(
                                          Event, InterceptorsCtx, ChannelCtx),
      {InterceptorsCtx2, ChannelCtx2, SinkCtx}
    end, FlowConfigs),
  {reply, ack, Ctx#{flows := Outputs2}};
handle_call({detach, SinkPidToDetach}, _From, #{flows := FlowConfigs2}=Ctx) ->
  {FlowConfigs, [Detached]} = lists:partition(fun({_, _, SinkCtx}) ->
      not stepflow_sink:is_module(SinkPidToDetach, SinkCtx)
    end, FlowConfigs2),
  {reply, {ok, Detached}, Ctx#{flows := FlowConfigs}};
handle_call({debug, flow}, _From, #{flows := FlowConfigs}=Ctx) ->
  {reply, FlowConfigs, Ctx}.

handle_cast(pop, #{flows := FlowConfigs}=Ctx) ->
  Outputs2 = lists:map(fun({InterceptorsCtx, ChannelCtx, SinkCtx}) ->
      {ChannelCtx2, SinkCtx2} = pop(ChannelCtx, SinkCtx),
      {InterceptorsCtx, ChannelCtx2, SinkCtx2}
    end, FlowConfigs),
  {noreply, Ctx#{flows := Outputs2}};
handle_cast({attach, FlowConfig}, #{flows := FlowConfigs2}=Ctx) ->
  {noreply, Ctx#{flows := [FlowConfig | FlowConfigs2]}};

handle_cast(_Event, Ctx) ->
  {noreply, Ctx}.

handle_info(_Info, Ctx) ->
  {noreply, Ctx}.

terminate(_Reason, _Ctx) ->
  io:format("Terminate!!~n"),
  ok.

code_change(_OldVsn, Ctx, _Extra) ->
  io:format("code changed !"),
  {ok, Ctx}.

%%====================================================================
%% Internal functions
%%====================================================================

-spec pop(chctx(), skctx()) -> {chctx(), skctx()}.
pop(ChannelCtx, SinkCtx) ->
  case stepflow_channel:pop(SinkCtx, ChannelCtx) of
    {ok, SinkCtx2, ChannelCtx2} -> {ChannelCtx2, SinkCtx2};
    {error, _} -> {ChannelCtx, SinkCtx}
  end.

append(Event, InterceptorsCtx, ChannelCtx) ->
  {EventTransformed, InterceptorsCtx2} = transform(Event, InterceptorsCtx),
  {ok, ChannelCtx2} = stepflow_channel:append(EventTransformed, ChannelCtx),
  {InterceptorsCtx2, ChannelCtx2}.

transform(Event, InterceptorsCtx) ->
  lists:foldr(fun(InterceptorCtx, {AccEvent, ItCtxs}) ->
      {ok, AccEvent2, InterceptorCtx2} = stepflow_interceptor:intercept(
                                        AccEvent, InterceptorCtx),
      {AccEvent2, [InterceptorCtx2 | ItCtxs]}
    end, {Event, []}, InterceptorsCtx).

-spec config_channel({atom(), any()}, any()) -> stepflow_channel:ctx().
config_channel({Channel, Config}, SinkCtx) ->
  {ok, ChannelCtx} = stepflow_channel:init(Channel, Config, SinkCtx),
  ChannelCtx.

-spec config_interceptors(list({atom(), any()})) -> stepflow_interceptor:ctx().
config_interceptors(InterceptorsConfig) ->
  lists:map(fun({Interceptor, Config}) ->
      {ok, InterceptorCtx} = stepflow_interceptor:init(Interceptor, Config),
      InterceptorCtx
    end, InterceptorsConfig).

-spec config_sink({atom(), any()}) -> stepflow_sink:ctx().
config_sink({Sink, Config}) ->
  {ok, SinkCtx} = stepflow_sink:init(Sink, Config),
  SinkCtx.
