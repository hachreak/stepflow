%%%-------------------------------------------------------------------
%% @doc stepflow channel
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_channel).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  append/2,
  init/3,
  pop/2
]).

-type chctx() :: #{module => atom(), ctx => ctx()}.
-type ctx()   :: any().
-type event() :: #{headers => map(), body => map()}.
-type skctx() :: stepflow_sink:ctx().

%% Callbacks

-callback handle_init(ctx(), skctx()) -> {ok, ctx()} | {error, term()}.

-callback handle_append(event(), ctx()) -> {ok, ctx()} | {error, term()}.

-callback handle_pop(skctx(), ctx()) -> {ok, skctx(), ctx()} | {error, term()}.

%%====================================================================
%% API
%%====================================================================

-spec init(atom(), ctx(), skctx()) -> {ok, chctx()}.
init(Module, Ctx, SinkCtx) ->
  {ok, Ctx2} = Module:handle_init(Ctx, SinkCtx),
  {ok, #{module => Module, ctx => Ctx2}}.

-spec append(event(), chctx()) -> {ok, chctx()} | {error, term()}.
append(Event, #{module := Module, ctx := Ctx}=ChCtx) ->
  newctx_append(Module:handle_append(Event, Ctx), ChCtx).

-spec pop(skctx(), chctx()) -> {ok, skctx(), chctx()} | {error, term()}.
pop(SinkCtx, #{module := Module, ctx := Ctx}=ChCtx) ->
  newctx_pop(Module:handle_pop(SinkCtx, Ctx), ChCtx).

%%====================================================================
%% Internal functions
%%====================================================================

newctx_append({ok, Ctx}, ChCtx) -> {ok, ChCtx#{ctx := Ctx}}.

newctx_pop({ok, SinkCtx, Ctx}, ChCtx) ->
  {ok, SinkCtx, ChCtx#{ctx := Ctx}};
newctx_pop({error, Error}, _ChCtx) ->
  {error, Error}.
