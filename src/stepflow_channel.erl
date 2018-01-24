%%%-------------------------------------------------------------------
%% @doc stepflow channel
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_channel).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(gen_server).

-export([
  append/2,
  pop/1
]).

-export([
  start_link/1,
  init/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  code_change/3,
  terminate/2
]).

-type ctx()   :: map().
-type event() :: stepflow_event:event().
-type skctx() :: stepflow_sink:ctx().


%% Callbacks

% @doc Confirm the event has been processed successfully. @end
-callback ack(ctx()) -> ctx().

% @doc Called in case the event has NOT been processed successfully. @end
-callback nack(ctx()) -> ctx().

-callback append(list(event()), ctx()) -> ctx().

% -callback pop() -> ok.

-callback init(map()) -> ctx().

-callback set_sink(skctx(), ctx()) -> ctx().

-callback handle_call(any(), any(), ctx()) -> {reply, any(), ctx()}.

-callback handle_cast(any(), ctx()) -> {noreply, ctx()}.

-callback handle_info(any(), ctx()) -> {noreply, ctx()}.

-callback disconnect(ctx()) -> ctx().

-callback connect(ctx()) -> ctx().

%%====================================================================
%% API
%%====================================================================

config_sink(none) -> none;
config_sink({Module, {IntConfig, SkConfig}}) ->
  {ok, SkCtx} = stepflow_sink:config(Module, SkConfig, IntConfig),
  SkCtx.

append(Pid, Events) -> gen_server:cast(Pid, {append, Events}).

pop(Pid) -> gen_server:cast(Pid, pop).

-spec start_link(ctx()) -> {ok, pid()} | ignore | {error, term()}.
start_link(Config) ->
  gen_server:start_link(?MODULE, [Config], []).

init([{SkConfig, {Module, Config}}]) ->
  ChCtx = Module:disconnect(Module:init(Config)),
  {SkCtx2, ChCtx2} = case config_sink(SkConfig) of
    none -> {none, Module:connect(ChCtx)};
    SkCtx -> {SkCtx, Module:set_sink(SkCtx, Module:connect(ChCtx))}
  end,
  {ok, #{ch => {Module, ChCtx2}, sk => SkCtx2}}.

handle_call(Msg, From, #{ch := {Module, ChCtx}}=Ctx) ->
  {Reply, Msg2, ChCtx2} = Module:handle_call(Msg, From, ChCtx),
  {Reply, Msg2, Ctx#{ch => {Module, ChCtx2}}}.

handle_cast({route, Events}, Ctx) -> do_route(Events, Ctx);

handle_cast({append, Events}, #{ch := {Module, ChCtx}}=Ctx) ->
  ChCtx2 = Module:append(Events, ChCtx),
  {noreply, Ctx#{ch => {Module, ChCtx2}}};

handle_cast(Msg, #{ch := {Module, ChCtx}}=Ctx) ->
  case Module:handle_cast(Msg, ChCtx) of
    {route, Events, ChCtx2} ->
      Ctx2 = do_route(Events, Ctx#{ch := {Module, ChCtx2}}),
      {noreply, Ctx2};
    {Reply, ChCtx2} ->
      {Reply, Ctx#{ch => {Module, ChCtx2}}}
  end.

handle_info(Msg, #{ch := {Module, ChCtx}}=Ctx) ->
  case Module:handle_info(Msg, ChCtx) of
    {route, Events, ChCtx2} ->
      Ctx2 = do_route(Events, Ctx#{ch := {Module, ChCtx2}}),
      {noreply, Ctx2};
    {Reply, ChCtx2} ->
      {Reply, Ctx#{ch => {Module, ChCtx2}}}
  end.

terminate(_Reason, _Ctx) ->
  io:format("Terminate!!~n"),
  ok.

code_change(_OldVsn, Ctx, _Extra) ->
  io:format("code changed !"),
  {ok, Ctx}.

%% API for behaviour implementations

do_route([], Ctx) -> Ctx;
do_route(_, #{ch := {Module, ChCtx}, sk := none}=Ctx) ->
  error_logger:warning_msg("[Channel] No sink connected!~n"),
  ChCtx2 = Module:nack(ChCtx),
  Ctx#{ch := {Module, ChCtx2}};
do_route(Events, #{ch := {Module, ChCtx}, sk := SkCtx}=Ctx) ->
  Ctx2 = case stepflow_sink:process(Events, SkCtx) of
    {ok, SkCtx2} ->
      % events processed!
      ChCtx2 = Module:ack(ChCtx),
      Ctx#{ch := {Module, ChCtx2}, sk := SkCtx2};
    {error, _} ->
      % something goes wrong! Leave memory as it is.
      ChCtx2 = Module:nack(ChCtx),
      Ctx#{ch := {Module, ChCtx2}}
  end,
  Ctx2.
