%%%-------------------------------------------------------------------
%% @doc stepflow interceptor echo
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_interceptor_echo).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_interceptor).

-export([
  %init/1,
  intercept/2
]).

-type event() :: stepflow_interceptor:event().
-type ctx()   :: stepflow_interceptor:ctx().

-spec intercept(event(), ctx()) -> ok.
intercept(Event, _Ctx) ->
  io:format("Intercepted: ~n~p~n~n", [Event]),
  Event.
