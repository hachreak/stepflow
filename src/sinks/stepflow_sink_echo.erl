%%%-------------------------------------------------------------------
%% @doc stepflow sink echo
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_sink_echo).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_sink).

-export([
  handle_init/1,
  handle_process/2
]).

-type event() :: stepflow_event:event().
-type ctx()   :: stepflow_sink:ctx().

-spec handle_init(ctx()) -> {ok, ctx()} | {error, term()}.
handle_init(_) -> {ok, #{}}.

-spec handle_process(list(event()), ctx()) -> {ok, ctx()} | {error, term()}.
handle_process(Events, Ctx) ->
  io:format("Events received: ~p~n", [Events]),
  {ok, Ctx}.
