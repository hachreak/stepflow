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

start_link([{_Interceptors, _Channel, _Sink} | _]=Outputs) ->
  gen_server:start_link(
    {local, ?MODULE}, ?MODULE, [Outputs], []).

%% Callbacks

init([Outputs]) ->
  process_flag(trap_exit, true),
  {ok, #{outputs => Outputs}}.

handle_call({append, Event}, _From, #{outputs := Outputs}=Ctx) ->
  Outputs2 = process(fun({InterceptorsCtx, ChannelCtx, _}) ->
      append(Event, InterceptorsCtx, ChannelCtx)
    end, Outputs),
  gen_server:cast(self(), pop),
  {reply, ack, Ctx#{outputs := Outputs2}}.

handle_cast(pop, #{outputs := Outputs}=Ctx) ->
  Outputs2 = process(fun({_, ChannelCtx, Sink}) ->
      % io:format("@@@FUUUU: ~p~n~n", [Fuu])
      pop(ChannelCtx, Sink)
    end, Outputs),
  {noreply, Ctx#{outputs := Outputs2}};

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

process(Fun, Outputs) ->
  lists:map(fun({InterceptorsCtx, _, Sink}=Output) ->
      ChannelCtx = Fun(Output),
      {InterceptorsCtx, ChannelCtx, Sink}
    end, Outputs).

pop(ChannelCtx, {SinkPid, SinkCtx}) ->
  {ok, ChannelCtx2} = stepflow_channel:pop(fun(Event) ->
      SinkPid:process(Event, SinkCtx)
    end, ChannelCtx),
  ChannelCtx2.

append(Event, InterceptorsCtx, ChannelCtx) ->
  {ok, ChannelCtx2} = stepflow_channel:append(
                        transform(Event, InterceptorsCtx), ChannelCtx),
  % gen_server:cast(self(), pop),
  ChannelCtx2.

transform(Event, InterceptorsCtx) ->
  lists:foldl(fun({InterceptorPid, InterceptorCtx}, AccEvent) ->
      InterceptorPid:intercept(AccEvent, InterceptorCtx)
    end, Event, InterceptorsCtx).
