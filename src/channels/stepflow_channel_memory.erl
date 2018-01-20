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
  nack/1,
  update_chctx/2
]).

-type ctx()   :: map().
-type event() :: stepflow_event:event().

%% Callbacks channel

-spec ack(ctx()) -> ctx().
ack(Ctx) -> reset_memory(Ctx).

-spec nack(ctx()) -> ctx().
nack(Ctx)-> Ctx.

update_chctx(Ctx, ChCtx) -> Ctx#{chctx => ChCtx}.

%% Callbacks gen_server

-spec start_link(ctx()) -> {ok, pid()} | ignore | {error, term()}.
start_link(Config) ->
  gen_server:start_link(?MODULE, [Config], []).

% -spec init(list(ctx())) -> {ok, ctx()}.
init([{SkCtx, Config}]) ->
  Config2 = case stepflow_channel:init(SkCtx) of
    {ok, ChCtx} -> Config#{chctx => ChCtx};
    no_sink -> Config
  end,
  % TODO enable in future if we need
  % erlang:start_timer(3000, self(), flush),
  {ok, reset_memory(Config2)}.

handle_call(debug, _From, Ctx) ->
  {reply, Ctx, Ctx};
handle_call(_, _From, Ctx) ->
  {reply, not_implemented, Ctx}.

handle_cast({append, Events}, Ctx) ->
  {noreply, do_append(Events, Ctx)};
handle_cast(pop, Ctx) ->
  {noreply, do_pop(Ctx)};
handle_cast(Msg, Ctx) ->
  error_logger:warning_msg("[Channel] not implemented ~p~n", [Msg]),

  {noreply, Ctx}.

handle_info(_Msg, Ctx) ->
  {noreply, Ctx}.

terminate(_Reason, _Ctx) ->
  io:format("Terminate!!~n"),
  ok.

code_change(_OldVsn, Ctx, _Extra) ->
  io:format("code changed !"),
  {ok, Ctx}.

%% Private functions

reset_memory(Ctx) -> Ctx#{memory => []}.

do_append(Events, #{memory := Memory}=Ctx) ->
  % save the new value
  Ctx2 = Ctx#{memory => lists:flatten([Events, Memory])},
  % trigger pop!
  stepflow_channel:pop(self()),
  Ctx2.

-spec do_pop(ctx()) -> {ok, ctx()} | {error, term()}.
do_pop(#{memory := []}=Ctx) -> Ctx;
do_pop(#{memory := Memory, chctx := ChCtx}=Ctx) ->
  stepflow_channel:route(?MODULE, Ctx, Memory, ChCtx).
