%%%-------------------------------------------------------------------
%% @doc stepflow interceptor echo
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_interceptor_echo).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_interceptor).

-export([
  handle_init/1,
  handle_intercept/2
]).

-type event() :: stepflow_event:event().
-type ctx()   :: stepflow_interceptor:ctx().

-spec handle_init(ctx()) -> {ok, ctx()} | {error, term()}.
handle_init(_) -> {ok, []}.

-spec handle_intercept(list(event()), ctx()) ->
    {ok, list(event()), ctx()} | {reject, ctx()} | {error, term()}.
handle_intercept(Events, Ctx) ->
  io:format("Intercepted: ~p~n", [Events]),
  {ok, Events, Ctx}.
