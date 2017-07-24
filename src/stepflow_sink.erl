%%%-------------------------------------------------------------------
%% @doc stepflow sink
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_sink).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  config/3,
  process/2
]).

-type ctx()   :: map().
-type event() :: stepflow_event:event().
-type inctx() :: stepflow_interceptor:ctx().
-type skctx() :: #{module => atom(), ctx => ctx(), inctxs => list(inctx())}.

%% Callbacks

-callback handle_init(ctx()) -> {ok, ctx()} | {error, term()}.

-callback handle_process(list(event()), ctx()) ->
    {ok, ctx()} | {error, term()}.

%%====================================================================
%% API
%%====================================================================

-spec config(atom(), ctx(), list({atom(), inctx()})) -> {ok, skctx()}.
config(Module, Ctx, InsConfig) ->
  {ok, Ctx2} = Module:handle_init(Ctx),
  InCtxs = stepflow_interceptor:init_all(InsConfig),
  {ok, #{module => Module, ctx => Ctx2, inctxs => InCtxs}}.

-spec process(list(event()), skctx()) ->
    {ok, skctx()} | {reject, skctx()} | {error, term()}.
process(Events, #{inctxs := InCtxs, module := Module, ctx := Ctx}=SkCtx) ->
  case stepflow_interceptor:transform(Events, InCtxs) of
    {ok, Events2, InCtxs2} ->
      newctx(Module:handle_process(Events2, Ctx), SkCtx#{inctxs => InCtxs2});
    {reject, InCtxs2} -> {reject, SkCtx#{inctxs => InCtxs2}}
    % TODO {stop, Events, InCtxs}
    % TODO {error, _}
  end.

%%====================================================================
%% Internal functions
%%====================================================================

newctx({ok, Ctx}, SkCtx) -> {ok, SkCtx#{ctx := Ctx}};
newctx({error, Error}, _SkCtx) -> {error, Error}.
