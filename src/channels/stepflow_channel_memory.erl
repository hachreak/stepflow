%%%-------------------------------------------------------------------
%% @doc stepflow channel memory
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_channel_memory).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_channel).

-export([
  ack/1,
  append/2,
  connect/1,
  disconnect/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  init/1,
  nack/1,
  pop/1,
  set_sink/2
]).

-type ctx()   :: map().

%% Callbacks channel

-spec ack(ctx()) -> ctx().
ack(Ctx) -> reset_memory(Ctx).

-spec nack(ctx()) -> ctx().
nack(Ctx)-> Ctx.

set_sink(_SkCtx, Ctx) -> Ctx.

%% Callbacks

% -spec init(list(ctx())) -> {ok, ctx()}.
init(Config) ->
  % TODO enable in future if we need
  % erlang:start_timer(3000, self(), flush),
  reset_memory(Config).

connect(Ctx) -> Ctx.

disconnect(Ctx) -> Ctx.

append(Events, Ctx) ->
  % trigger pop!
  stepflow_channel:pop(self()),
  do_append(Events, Ctx).

pop(Ctx) -> do_pop(Ctx).

handle_call(Msg, _From, Ctx) ->
  error_logger:warning_msg("[Channel] not implemented ~p~n", [Msg]),
  {reply, not_implemented, Ctx}.

handle_cast(Msg, Ctx) ->
  error_logger:warning_msg("[Channel] not implemented ~p~n", [Msg]),
  {noreply, Ctx}.

handle_info(_Msg, Ctx) ->
  {noreply, Ctx}.

%% Private functions

reset_memory(Ctx) -> Ctx#{memory => []}.

do_append(Events, #{memory := Memory}=Ctx) ->
  % save the new value
  Ctx#{memory => lists:flatten([Events, Memory])}.

% do_pop(#{memory := []}=Ctx) -> {noreply, Ctx};
do_pop(#{memory := Memory}=Ctx) ->
  {Memory, Ctx}.
