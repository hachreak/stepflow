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
  ack/1,
  config/1,
  nack/1
]).

-type ctx()   :: map().
-type event() :: stepflow_event:event().

%% Callbacks channel

-spec config(ctx()) -> {ok, ctx()}  | {error, term()}.
config(Config) -> {ok, Config}.

-spec ack(ctx()) -> ctx().
ack(Ctx) -> reset(Ctx).

-spec nack(ctx()) -> ctx().
nack(Ctx)-> Ctx.

%% Callbacks gen_server

-spec start_link(ctx()) -> {ok, pid()} | ignore | {error, term()}.
start_link(Config) ->
  gen_server:start_link(?MODULE, [Config], []).

-spec init(list(ctx())) -> {ok, ctx()}.
init([Config]) ->
  % TODO enable in future if we need
  % erlang:start_timer(3000, self(), flush),
  {ok, reset(Config)}.

-spec handle_call(any(), {pid(), term()}, ctx()) -> {reply, ok, ctx()}.
handle_call(Msg, From, Ctx) ->
  stepflow_channel:handle_call(Msg, From, Ctx).

-spec handle_cast({append, list(event())} | pop, ctx()) -> {noreply, ctx()}.
handle_cast({append, Events}, Ctx) ->
  {noreply, append(Events, Ctx)};
handle_cast(pop, Ctx) ->
  {noreply, pop(Ctx)};
handle_cast(Msg, Ctx) -> stepflow_channel:handle_cast(Msg, Ctx).

handle_info({timeout, _, flush}, Ctx) ->
  io:format("Flush memory.. ~p~n", [maps:get(memory, Ctx)]),
  {noreply, flush({ok, Ctx}, Ctx)};
handle_info(Msg, Ctx) -> stepflow_channel:handle_info(Msg, Ctx).

terminate(_Reason, _Ctx) ->
  io:format("Terminate!!~n"),
  ok.

code_change(_OldVsn, Ctx, _Extra) ->
  io:format("code changed !"),
  {ok, Ctx}.

%% Private functions

reset(Ctx) -> Ctx#{memory => []}.

append(Events, #{memory := Memory}=Ctx) ->
  % save the new value
  Ctx2 = Ctx#{memory => lists:flatten([Events, Memory])},
  % trigger pop!
  stepflow_channel:pop(self()),
  Ctx2.

flush(#{memory := []}, Ctx) ->
  erlang:start_timer(5000, self(), flush),
  Ctx#{memory => []};
flush({ok, Ctx2}, _Ctx) -> flush(pop(Ctx2), Ctx2).

-spec pop(ctx()) -> {ok, ctx()} | {error, term()}.
pop(#{memory := []}=Ctx) -> Ctx;
pop(#{memory := Memory}=Ctx) ->
  stepflow_channel:route(?MODULE, Memory, Ctx).
