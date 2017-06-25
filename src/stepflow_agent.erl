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

-type chctx() :: stepflow_channel:chctx().
-type skctx() :: stepflow_sink:skctx().

%%====================================================================
%% API
%%====================================================================

start_link([{_Interceptors, _Channel, _Sink} | _]=FlowConfigs) ->
  gen_server:start_link(?MODULE, [FlowConfigs], []).

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
  gen_server:cast(self(), pop),
  {reply, ack, Ctx#{flows := Outputs2}}.

handle_cast(pop, #{flows := FlowConfigs}=Ctx) ->
  Outputs2 = lists:map(fun({InterceptorsCtx, ChannelCtx, SinkCtx}) ->
      {ChannelCtx2, SinkCtx2} = pop(ChannelCtx, SinkCtx),
      {InterceptorsCtx, ChannelCtx2, SinkCtx2}
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

-spec pop(chctx(), skctx()) -> {chctx(), skctx()}.
pop(ChannelCtx, SinkCtx) ->
  {ok, SinkCtx2, ChannelCtx2} = stepflow_channel:pop(fun(Event) ->
      stepflow_sink:process(Event, SinkCtx)
    end, ChannelCtx),
  {ChannelCtx2, SinkCtx2}.

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
