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

-type event() :: stepflow_event:event().
-type ctx()   :: any().
-type itctx() :: #{module => atom(), ctx => ctx()}.

%% Callbacks

-callback handle_init(ctx()) -> {ok, ctx()} | {error, term()}.

-callback handle_intercept(list(event()), ctx()) ->
    {ok, list(event()), ctx()} | {reject, ctx()} | {error, term()}.

%%====================================================================
%% API
%%====================================================================

-spec init(atom(), ctx()) -> {ok, itctx()}.
init(Module, Ctx) ->
  {ok, Ctx2} = Module:handle_init(Ctx),
  {ok, #{module => Module, ctx => Ctx2}}.

-spec intercept(list(event()), itctx()) ->
    {ok, list(event()), ctx()} | {reject, ctx()} | {error, term()}.
intercept(Events, #{module := Module, ctx := Ctx}=ItCtx) ->
  newctx(Module:handle_intercept(Events, Ctx), ItCtx).

-spec init_all(list({atom(), ctx()})) -> list(ctx()).
init_all(InterceptorsConfig) ->
  lists:map(fun({Interceptor, Config}) ->
      {ok, InterceptorCtx} = init(Interceptor, Config),
      InterceptorCtx
    end, InterceptorsConfig).

-spec transform(list(event()), list(ctx())) ->
    {ok, list(event()), list(ctx())} | {reject, list(ctx())}.
transform(Events, []) -> {ok, Events, []};
transform(Events, [ItCtx | Rest]) ->
  transform(intercept(Events, ItCtx), Rest, []).

%%====================================================================
%% Internal functions
%%====================================================================

transform({ok, Events, ItCtxOut}, [], ItCtxOuts) ->
  {ok, Events, [ItCtxOut | ItCtxOuts]};
transform({ok, Events, ItCtxOut}, [ItCtxIn | Rest], ItCtxOuts) ->
  transform(intercept(Events, ItCtxIn), Rest, [ItCtxOut | ItCtxOuts]);
transform({reject, ItCtxOut}, ItCtxs, ItCtxOuts) ->
  {reject, lists:flatten([[ItCtxOut], ItCtxs, ItCtxOuts])}.

newctx({ok, Events, Ctx}, ItCtx) -> {ok, Events, ItCtx#{ctx := Ctx}};
% newctx({stop, Events, Ctx}, ItCtx) -> {stop, Events, ItCtx#{ctx := Ctx}};
newctx({reject, Ctx}, ItCtx) -> {reject, ItCtx#{ctx := Ctx}};
newctx({error, _}=Error, _) -> Error.
