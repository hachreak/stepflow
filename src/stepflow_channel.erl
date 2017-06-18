%%%-------------------------------------------------------------------
%% @doc stepflow channel
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_channel).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  append/2,
  init/2,
  pop/2
]).

-type chctx() :: #{module => atom(), ctx => ctx()}.
-type ctx()   :: any().
-type event() :: #{headers => map(), body => map()}.

%% Callbacks

-callback handle_init(ctx()) -> {ok, ctx()} | {error, term()}.

-callback handle_append(event(), ctx()) -> {ok, ctx()} | {error, term()}.

-callback handle_pop(fun(), ctx()) -> {ok, event(), ctx()} | {error, term()}.

-callback handle_transaction_begin() -> ok.

-callback handle_transaction_commit() -> ok.

-callback handle_transaction_end() -> ok.

%%====================================================================
%% API
%%====================================================================

-spec init(atom(), ctx()) -> {ok, chctx()}.
init(Module, Ctx) ->
  {ok, Ctx2} = Module:handle_init(Ctx),
  {ok, #{module => Module, ctx => Ctx2}}.

-spec append(event(), chctx()) -> {ok, chctx()} | {error, term()}.
append(Event, #{module := Module, ctx := Ctx}=ChCtx) ->
  newctx(Module:handle_append(Event, Ctx), ChCtx).

-spec pop(fun(), chctx()) -> {ok, event(), chctx()} | {error, term()}.
pop(Fun, #{module := Module, ctx := Ctx}=ChCtx) ->
  newctx(Module:handle_pop(Fun, Ctx), ChCtx).

%%====================================================================
%% Internal functions
%%====================================================================

newctx({ok, Ctx}, ChCtx) -> {ok, ChCtx#{ctx := Ctx}}.
