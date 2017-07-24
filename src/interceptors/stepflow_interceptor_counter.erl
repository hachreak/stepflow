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
handle_init(#{eval := Eval}=Ctx) ->
  Header = maps:get(header, Ctx, counter),
  {ok, #{eval => Eval, counter => 0, header => Header}};
handle_init(Ctx) ->
  Eval = fun(_) -> true end,
  handle_init(Ctx#{eval => Eval}).

-spec handle_intercept(list(event()), ctx()) ->
    {ok, list(event()), ctx()} | {reject, ctx()} | {error, term()}.
handle_intercept(Events, #{eval := Eval, header := Header,
                          counter := Counter}=Ctx) ->
  Counter2 = inc(Eval(Events), Counter),
  Events2 = [stepflow_event:header(Header, Counter2, Event)
             || Event <- Events],
  io:format("Counter: ~p~n", [Counter2]),
  {ok, Events2, Ctx#{counter => Counter2}}.

%% Private functions

inc(true, Counter) -> Counter + 1;
inc(false, Counter) -> Counter.
