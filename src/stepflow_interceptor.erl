%%%-------------------------------------------------------------------
%% @doc stepflow interceptor
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_interceptor).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  init/2,
  init_all/1,
  intercept/2,
  transform/2
]).

-type event() :: stepflow_agent:event().
-type ctx()   :: any().
-type itctx() :: #{module => atom(), ctx => ctx()}.

%% Callbacks

-callback handle_init(ctx()) -> {ok, ctx()} | {error, term()}.

-callback handle_intercept(event(), ctx()) ->
    {ok, event(), ctx()} | {reject, ctx()} | {error, term()}.

%%====================================================================
%% API
%%====================================================================

-spec init(atom(), ctx()) -> {ok, itctx()}.
init(Module, Ctx) ->
  {ok, Ctx2} = Module:handle_init(Ctx),
  {ok, #{module => Module, ctx => Ctx2}}.

-spec intercept(event(), itctx()) ->
    {ok, event(), ctx()} | {reject, ctx()} | {error, term()}.
intercept(Event, #{module := Module, ctx := Ctx}=ItCtx) ->
  newctx(Module:handle_intercept(Event, Ctx), ItCtx).

-spec init_all(list({atom(), ctx()})) -> list(ctx()).
init_all(InterceptorsConfig) ->
  lists:map(fun({Interceptor, Config}) ->
      {ok, InterceptorCtx} = init(Interceptor, Config),
      InterceptorCtx
    end, InterceptorsConfig).

-spec transform(event(), list(ctx())) ->
    {ok, event(), list(ctx())} | {reject, list(ctx())}.
transform(Event, []) -> {ok, Event, []};
transform(Event, [ItCtx | Rest]) ->
  transform(intercept(Event, ItCtx), Rest, []).

%%====================================================================
%% Internal functions
%%====================================================================

transform({ok, Event, ItCtxOut}, [], ItCtxOuts) ->
  {ok, Event, [ItCtxOut | ItCtxOuts]};
transform({ok, Event, ItCtxOut}, [ItCtxIn | Rest], ItCtxOuts) ->
  transform(intercept(Event, ItCtxIn), Rest, [ItCtxOut | ItCtxOuts]);
transform({reject, ItCtxOut}, ItCtxs, ItCtxOuts) ->
  {reject, lists:flatten([[ItCtxOut], ItCtxs, ItCtxOuts])}.

newctx({ok, Event, Ctx}, ItCtx) -> {ok, Event, ItCtx#{ctx := Ctx}};
% newctx({stop, Event, Ctx}, ItCtx) -> {stop, Event, ItCtx#{ctx := Ctx}};
newctx({reject, Ctx}, ItCtx) -> {reject, ItCtx#{ctx := Ctx}};
newctx({error, _}=Error, _) -> Error.
