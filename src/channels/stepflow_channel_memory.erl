%%%-------------------------------------------------------------------
%% @doc stepflow channel memory
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_channel_memory).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_channel).
-behaviour(gen_server).

-export([
  start_link/1,
  init/1,
  code_change/3,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2
]).

-export([
  config/1
]).

-type ctx()   :: map().
-type event() :: stepflow_channel:event().
-type skctx() :: stepflow_channel:skctx().

%% API

-spec config(ctx()) -> {ok, ctx()}  | {error, term()}.
config(Config) -> {ok, Config}.

%% Callbacks gen_server

-spec start_link(ctx()) -> {ok, pid()} | ignore | {error, term()}.
start_link(Config) ->
  gen_server:start_link(?MODULE, [Config], []).

-spec init(list(ctx())) -> {ok, ctx()}.
init([Config]) ->
  % TODO enable in future if we need
  % erlang:start_timer(3000, self(), flush),
  {ok, Config#{memory => []}}.

-spec handle_call(setup | {connect_sink, skctx()}, {pid(), term()}, ctx()) ->
    {reply, ok, ctx()}.
handle_call(setup, _From, Ctx) ->
  {reply, ok, Ctx};
handle_call({connect_sink, SinkCtx}, _From, Ctx) ->
  Ctx2 = Ctx#{skctx => SinkCtx},
  {reply, ok, Ctx2};
handle_call(Input, _From, Ctx) ->
  {reply, Input, Ctx}.

-spec handle_cast({append, event()} | pop, ctx()) -> {noreply, ctx()}.
handle_cast({append, Event}, #{memory := Memory}=Ctx) ->
  Ctx2 = Ctx#{memory =>[Event | Memory]},
  stepflow_channel:pop(self()),
  {noreply, Ctx2};
handle_cast(pop, Ctx) ->
  case pop(Ctx) of
    {error, _} -> {noreply, Ctx};
    {ok, Ctx2} -> {noreply, Ctx2}
  end;
handle_cast(_, Ctx) ->
  {noreply, Ctx}.

handle_info({timeout, _, flush}, Ctx) ->
  io:format("Flush memory.. ~p~n", [maps:get(memory, Ctx)]),
  Ctx2 = flush({ok, Ctx}, Ctx),
  erlang:start_timer(5000, self(), flush),
  {noreply, Ctx2};
handle_info(_Info, Ctx) ->
  {noreply, Ctx}.

terminate(_Reason, _Ctx) ->
  io:format("Terminate!!~n"),
  ok.

code_change(_OldVsn, Ctx, _Extra) ->
  io:format("code changed !"),
  {ok, Ctx}.

%% Private functions

flush({error, empty}, Ctx) -> Ctx#{memory => []};
flush({ok, Ctx2}, _Ctx) -> flush(pop(Ctx2), Ctx2).

-spec pop(ctx()) -> {ok, ctx()} | {error, term()}.
pop(#{memory := []}) -> {error, empty};
pop(#{skctx := SinkCtx, memory := Memory}) ->
  io:format("memory: ~p~n", [Memory]),
  Event = lists:last(Memory),
  % get event
  % execute the fun (e.g. move to anothe channel)
  case stepflow_sink:process(Event, SinkCtx) of
    {ok, SinkCtx2} ->
      % ack received, I can remove the event from memory
      {ok, #{skctx => SinkCtx2, memory => lists:droplast(Memory)}};
    {reject, SinkCtx2} ->
      {ok, #{skctx => SinkCtx2, memory => lists:droplast(Memory)}};
    {error, _}=Error ->
      % something goes wrong! Leave memory as it is.
      Error
  end.
