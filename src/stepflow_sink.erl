%%%-------------------------------------------------------------------
%% @doc stepflow sink
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_sink).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  config/2,
  is_module/2,
  process/2
]).

-type ctx()   :: any().
-type event() :: stepflow_agent:event().
-type skctx() :: #{module => atom(), ctx => ctx()}.

%% Callbacks

-callback handle_init(ctx()) -> {ok, ctx()} | {error, term()}.

-callback handle_process(event(), ctx()) -> {ok, ctx()} | {error, term()}.

-callback handle_is_module(erlang:pid(), ctx()) -> boolean().

%%====================================================================
%% API
%%====================================================================

-spec config(atom(), any()) -> {ok, skctx()}.
config(Module, Ctx) ->
  {ok, Ctx2} = Module:handle_init(Ctx),
  {ok, #{module => Module, ctx => Ctx2}}.

-spec process(event(), skctx()) -> {ok, skctx()} | {error, term()}.
process(Event, #{module := Module, ctx := Ctx}=SkCtx) ->
  newctx(Module:handle_process(Event, Ctx), SkCtx).

-spec is_module(erlang:pid(), skctx()) -> boolean().
is_module(Pid, #{module := Module, ctx := Ctx}) ->
  Module:handle_is_module(Pid, Ctx).

%%====================================================================
%% Internal functions
%%====================================================================

newctx({ok, Ctx}, SkCtx) -> {ok, SkCtx#{ctx := Ctx}};
newctx({error, Error}, _SkCtx) -> {error, Error}.
