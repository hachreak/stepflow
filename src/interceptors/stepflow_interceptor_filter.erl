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

-type event() :: stepflow_interceptor:event().
-type ctx()   :: stepflow_interceptor:ctx().

-spec handle_init(ctx()) -> {ok, ctx()} | {error, term()}.
handle_init(#{filter := Fun}) ->
  {ok, #{eval => Fun}};
handle_init(_) ->
  Eval = fun(_) -> false end,
  {ok, #{eval => Eval}}.

-spec handle_intercept(event(), ctx()) ->
    {ok, event(), ctx()} | {reject, ctx()} | {error, term()}.
handle_intercept(Event, #{eval := Eval}=Ctx) ->
  maybe_filter(Eval(Event), Event, Ctx).

%% Private functions

maybe_filter(true, Event, Ctx) ->
  io:format("Event filtered: ~p~n", [Event]),
  {reject, Ctx};
maybe_filter(false, Event, Ctx) -> {ok, Event, Ctx}.
