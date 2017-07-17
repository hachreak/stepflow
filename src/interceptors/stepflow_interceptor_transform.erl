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
  Eval = fun(Event) -> Event end,
  {ok, #{eval => Eval}}.

-spec handle_intercept(event(), ctx()) ->
    {ok, event(), ctx()} | {reject, ctx()} | {error, term()}.
handle_intercept(Event, #{eval := Eval}=Ctx) ->
  Transformed = Eval(Event),
  io:format("Transform: ~p~n", [Transformed]),
  {ok, Transformed, Ctx}.
