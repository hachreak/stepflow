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

-type event() :: stepflow_sink:event().
-type ctx()   :: stepflow_sink:ctx().

-spec handle_init(ctx()) -> {ok, ctx()} | {error, term()}.
handle_init(_) -> {ok, #{}}.

-spec handle_process(event(), ctx()) -> {ok, ctx()} | {error, term()}.
handle_process(Event, Ctx) ->
  io:format("Event received: ~p~n", [Event]),
  {ok, Ctx}.
