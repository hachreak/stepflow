%%%-------------------------------------------------------------------
%% @doc stepflow agent
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_agent).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(gen_server).

-export([
  start_link/3
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

start_link(Interceptors, Channel, Sink) ->
  gen_server:start_link(
    {local, ?MODULE}, ?MODULE, [Interceptors, Channel, Sink], []).

%% Callbacks

init([Interceptors, ChannelCtx, {_SPid, _SCtx}=Sink]) ->
  process_flag(trap_exit, true),
  {ok, #{interceptors => Interceptors, channel => ChannelCtx, sink => Sink}}.

handle_call({append, Event}, _From, #{interceptors := Interceptors,
                                      channel := ChannelCtx}=Ctx) ->
  {ok, ChannelCtx2} = stepflow_channel:append(
                        transform(Event, Interceptors), ChannelCtx),
  gen_server:cast(self(), pop),
  {reply, ack, Ctx#{channel => ChannelCtx2}}.

handle_cast(pop, #{channel := ChannelCtx, sink := {SinkPid, SinkCtx}}=Ctx) ->
  {ok, ChannelCtx2} = stepflow_channel:pop(fun(Event) ->
      SinkPid:process(Event, SinkCtx)
    end, ChannelCtx),
  {noreply, Ctx#{channel => ChannelCtx2}};

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

transform(Event, Interceptors) ->
  lists:foldl(fun({InterceptorPid, InterceptorCtx}, AccEvent) ->
      InterceptorPid:intercept(AccEvent, InterceptorCtx)
    end, Event, Interceptors).
