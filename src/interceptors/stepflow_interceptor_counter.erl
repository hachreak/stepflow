%%%-------------------------------------------------------------------
%% @doc stepflow interceptor counter: count the number of messages.
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_interceptor_counter).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_interceptor).

-export([
  handle_init/1,
  handle_intercept/2
]).

-type event() :: stepflow_event:event().
-type ctx()   :: stepflow_interceptor:ctx().

-spec handle_init(ctx()) -> {ok, ctx()} | {error, term()}.
handle_init({Module, Fun}) ->
  Eval = fun(Event) -> Module:Fun(Event) end,
  {ok, #{eval => Eval, counter => 0}};
handle_init(_) ->
  Eval = fun(_) -> true end,
  {ok, #{eval => Eval, counter => 0}}.

-spec handle_intercept(event(), ctx()) ->
    {ok, event(), ctx()} | {reject, ctx()} | {error, term()}.
handle_intercept(Event, #{eval := Eval, counter := Counter}=Ctx) ->
  Counter2 = inc(Eval(Event), Counter),
  io:format("Counter: ~p~n", [Counter2]),
  {ok, Event, Ctx#{counter => Counter2}}.

%% Private functions

inc(true, Counter) -> Counter + 1;
inc(false, Counter) -> Counter.
