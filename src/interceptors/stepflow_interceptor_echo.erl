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

-type event() :: stepflow_interceptor:event().
-type ctx()   :: stepflow_interceptor:ctx().

-spec handle_init(ctx()) -> {ok, ctx()} | {error, term()}.
handle_init(_) -> {ok, []}.

-spec handle_intercept(event(), ctx()) ->
    {ok, event(), ctx()} | {stop, event(), ctx()} | {error, term()}.
handle_intercept(Event, Ctx) ->
  io:format("Intercepted: ~n~p~n~n", [Event]),
  {ok, Event, Ctx}.
