%%%-------------------------------------------------------------------
%% @doc stepflow interceptor transorm: apply a function
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_interceptor_transform).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_interceptor).

-export([
  handle_init/1,
  handle_intercept/2
]).

-type event() :: stepflow_event:event().
-type ctx()   :: stepflow_interceptor:ctx().

-spec handle_init(ctx()) -> {ok, ctx()} | {error, term()}.
handle_init(#{eval := Fun}) ->
  {ok, #{eval => Fun}};
handle_init(_) ->
  Eval = fun(Events) -> Events end,
  {ok, #{eval => Eval}}.

-spec handle_intercept(list(event()), ctx()) ->
    {ok, list(event()), ctx()} | {reject, ctx()} | {error, term()}.
handle_intercept(Events, #{eval := Eval}=Ctx) ->
  case Eval(Events) of
    {ok, Transformed} ->
      io:format("Transform: ~p~n", [Transformed]),
      {ok, Transformed, Ctx};
    reject -> {reject, Ctx};
    {error, _}=Error -> Error
  end.
