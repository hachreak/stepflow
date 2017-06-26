%%%-------------------------------------------------------------------
%% @doc stepflow channel
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_channel).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  append/2,
  init/2,
  pop/3
]).

-type chctx() :: #{module => atom(), ctx => ctx()}.
-type ctx()   :: any().
-type event() :: #{headers => map(), body => map()}.
-type skctx() :: stepflow_sink:ctx().

%% Callbacks

-callback handle_init(ctx()) -> {ok, ctx()} | {error, term()}.

-callback handle_append(event(), ctx()) -> {ok, ctx()} | {error, term()}.

-callback handle_pop(fun(), skctx(), ctx()) ->
    {ok, skctx(), ctx()} | {error, term()}.

-callback handle_has_more(ctx()) -> {boolean(), ctx()}.

%%====================================================================
%% API
%%====================================================================

-spec init(atom(), ctx()) -> {ok, chctx()}.
init(Module, Ctx) ->
  {ok, Ctx2} = Module:handle_init(Ctx),
  {ok, #{module => Module, ctx => Ctx2}}.

-spec append(event(), chctx()) -> {ok, chctx()} | {error, term()}.
append(Event, #{module := Module, ctx := Ctx}=ChCtx) ->
  newctx_append(Module:handle_append(Event, Ctx), ChCtx).

-spec pop(fun(), skctx(), chctx()) -> {ok, skctx(), chctx()} | {error, term()}.
pop(Fun, SinkCtx, #{module := Module, ctx := Ctx}=ChCtx) ->
  % case Module:handle_has_more(Ctx) of
    % {true, Ctx2} ->
      % newctx_pop(Module:handle_pop(Fun, SinkCtx, Ctx), Module, Fun, ChCtx).
  newctx_pop({ok, SinkCtx, Ctx}, Module, Fun, ChCtx).

%%====================================================================
%% Internal functions
%%====================================================================

newctx_append({ok, Ctx}, ChCtx) -> {ok, ChCtx#{ctx := Ctx}}.

newctx_pop({ok, SinkCtx, Ctx}, Module, Fun, ChCtx) ->
  case Module:handle_has_more(Ctx) of
    {true, Ctx2} ->
      newctx_pop(Module:handle_pop(Fun, SinkCtx, Ctx),
                 Module, Fun, ChCtx#{ctx := Ctx2});
    {false, Ctx2} ->
      {ok, SinkCtx, ChCtx#{ctx := Ctx2}}
  end;
newctx_pop({error, Error}, _Module, _Fun, _ChCtx) ->
  {error, Error}.
