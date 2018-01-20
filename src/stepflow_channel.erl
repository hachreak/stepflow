%%%-------------------------------------------------------------------
%% @doc stepflow channel
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_channel).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  init/1,
  route/4,
  pop/1,
  append/2,
  debug/1
]).

-type ctx()   :: map().
-type event() :: stepflow_event:event().
-type skctx() :: stepflow_sink:ctx().


%% Callbacks

% @doc Confirm the event has been processed successfully. @end
-callback ack(ctx()) -> ctx().

% @doc Called in case the event has NOT been processed successfully. @end
-callback nack(ctx()) -> ctx().

%-callback pop()

%%====================================================================
%% API
%%====================================================================

init(none) -> {ok, no_sink};
init({Module, {InterceptorsConfig, SkConfig}}) ->
  {ok, SkCtx} = stepflow_sink:config(Module, SkConfig, InterceptorsConfig),
  {ok, #{skctx => SkCtx}}.

append(Pid, Events) ->
  gen_server:cast(Pid, {append, Events}).

pop(Pid) ->
  gen_server:cast(Pid, pop).

debug(Pid) ->
  gen_server:call(Pid, debug).

%% API for behaviour implementations

-spec route(atom(), ctx(), list(event()), ctx()) -> ctx().
route(_, ModuleCtx, [], _) -> ModuleCtx;
route(Module, ModuleCtx, Events, #{skctx := SinkCtx}) ->
  case stepflow_sink:process(Events, SinkCtx) of
    {ok, SinkCtx2} ->
      % events processed!
      Module:ack(Module:update_chctx(ModuleCtx, #{skctx => SinkCtx2}));
    {error, _} ->
      % something goes wrong! Leave memory as it is.
      Module:nack(ModuleCtx)
  end;
route(Module, ModuleCtx, _, _) ->
  error_logger:warning_msg("[Channel] No sink connected!~n"),
  Module:nack(ModuleCtx).
