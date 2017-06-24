%%%-------------------------------------------------------------------
%% @doc stepflow agent
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_agent).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(gen_server).

-export([
  start_link/1
]).

%% Callbacks
-export([
  init/1,
  code_change/3,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2
]).

%%====================================================================
%% API
%%====================================================================

start_link([{_Interceptors, _Channel, _Sink} | _]=FlowConfigs) ->
  gen_server:start_link(
    {local, ?MODULE}, ?MODULE, [FlowConfigs], []).

%% Callbacks

init([FlowConfigs]) ->
  process_flag(trap_exit, true),
  {ok, #{flows => FlowConfigs}}.

handle_call({append, Event}, _From, #{flows := FlowConfigs}=Ctx) ->
  Outputs2 = process(fun({InterceptorsCtx, ChannelCtx, _}) ->
      append(Event, InterceptorsCtx, ChannelCtx)
    end, FlowConfigs),
  gen_server:cast(self(), pop),
  {reply, ack, Ctx#{flows := Outputs2}}.

handle_cast(pop, #{flows := FlowConfigs}=Ctx) ->
  Outputs2 = process(fun({_, ChannelCtx, Sink}) ->
      pop(ChannelCtx, Sink)
    end, FlowConfigs),
  {noreply, Ctx#{flows := Outputs2}};

handle_cast(_Event, Ctx) ->
  {noreply, Ctx}.

handle_info(_Info, Ctx) ->
  {noreply, Ctx}.

terminate(_Reason, _Ctx) ->
  ok.

code_change(_OldVsn, Ctx, _Extra) ->
  io:format("code changed !"),
  {ok, Ctx}.

%%====================================================================
%% Internal functions
%%====================================================================

process(Fun, FlowConfigs) ->
  lists:map(fun({InterceptorsCtx, _, Sink}=Output) ->
      ChannelCtx = Fun(Output),
      {InterceptorsCtx, ChannelCtx, Sink}
    end, FlowConfigs).

pop(ChannelCtx, {SinkPid, SinkCtx}) ->
  {ok, ChannelCtx2} = stepflow_channel:pop(fun(Event) ->
      SinkPid:process(Event, SinkCtx)
    end, ChannelCtx),
  ChannelCtx2.

append(Event, InterceptorsCtx, ChannelCtx) ->
  {ok, ChannelCtx2} = stepflow_channel:append(
                        transform(Event, InterceptorsCtx), ChannelCtx),
  ChannelCtx2.

transform(Event, InterceptorsCtx) ->
  lists:foldl(fun({InterceptorPid, InterceptorCtx}, AccEvent) ->
      InterceptorPid:intercept(AccEvent, InterceptorCtx)
    end, Event, InterceptorsCtx).
