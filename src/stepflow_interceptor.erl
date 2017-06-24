%%%-------------------------------------------------------------------
%% @doc stepflow interceptor
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_interceptor).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  init/2,
  intercept/2
]).

-type event() :: stepflow_agent:event().
-type ctx()   :: any().
-type itctx() :: #{module => atom(), ctx => ctx()}.

%% Callbacks

-callback handle_init(ctx()) -> {ok, ctx()} | {error, term()}.

-callback handle_intercept(event(), ctx()) ->
    {ok, event(), ctx()} | {stop, event(), ctx()} | {error, term()}.

%%====================================================================
%% API
%%====================================================================

-spec init(atom(), ctx()) -> {ok, itctx()}.
init(Module, Ctx) ->
  {ok, Ctx2} = Module:handle_init(Ctx),
  {ok, #{module => Module, ctx => Ctx2}}.

-spec intercept(event(), itctx()) ->
    {ok, event(), ctx()} | {stop, event(), ctx()} | {error, term()}.
intercept(Event, #{module := Module, ctx := Ctx}=SrCtx) ->
  newctx(Module:handle_intercept(Event, Ctx), SrCtx).

%%====================================================================
%% Internal functions
%%====================================================================

newctx({ok, Event, Ctx}, SrCtx) -> {ok, Event, SrCtx#{ctx := Ctx}};
newctx({stop, Event, Ctx}, SrCtx) -> {stop, Event, SrCtx#{ctx := Ctx}};
newctx({error, _}=Error, _) -> Error.
