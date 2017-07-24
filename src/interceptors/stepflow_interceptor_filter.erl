%%%-------------------------------------------------------------------
%% @doc stepflow interceptor filter: filter events.
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_interceptor_filter).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_interceptor).

-export([
  handle_init/1,
  handle_intercept/2
]).

-type event() :: stepflow_event:event().
-type ctx()   :: stepflow_interceptor:ctx().

-spec handle_init(ctx()) -> {ok, ctx()} | {error, term()}.
handle_init(#{filter := Fun}) ->
  {ok, #{eval => Fun}};
handle_init(_) ->
  Eval = fun(_) -> false end,
  {ok, #{eval => Eval}}.

-spec handle_intercept(list(event()), ctx()) ->
    {ok, list(event()), ctx()} | {reject, ctx()} | {error, term()}.
handle_intercept(Events, #{eval := Eval}=Ctx) ->
  maybe_filter(Eval(Events), Events, Ctx).

%% Private functions

maybe_filter(true, Events, Ctx) ->
  io:format("Events filtered: ~p~n", [Events]),
  {reject, Ctx};
maybe_filter(false, Events, Ctx) -> {ok, Events, Ctx}.
