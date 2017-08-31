%%%-------------------------------------------------------------------
%% @doc stepflow channel
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_channel).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  append/2,
  setup/1,
  connect_sink/2,
  debug/4,
  pop/1,
  route/3
]).

-export([
  handle_call/3,
  handle_cast/2,
  handle_info/2
]).

-export_type([event/0]).

-type ctx()   :: map().
-type event() :: stepflow_event:event().
-type skctx() :: stepflow_sink:ctx().

%% Callbacks

% @doc Configure channel implementation.
% @end
-callback config(ctx()) -> {ok, ctx()}  | {error, term()}.

% @doc Confirm the event has been processed successfully.
% @end
-callback ack(ctx()) -> ctx().

% @end Called in case the event has NOT been processed successfully.
% @end
-callback nack(ctx()) -> ctx().

%%====================================================================
%% API
%%====================================================================

-spec connect_sink(pid(), skctx()) -> ok.
connect_sink(Pid, SinkCtx) -> gen_server:call(Pid, {connect_sink, SinkCtx}).

-spec setup(pid()) -> ok.
setup(Pid) -> gen_server:call(Pid, setup).

-spec pop(pid()) -> ok.
pop(Pid) -> gen_server:cast(Pid, pop).

-spec append(pid(), list(event())) -> ok.
append(Pid, Events) -> gen_server:cast(Pid, {append, Events}).

-spec route(atom(), list(event()), ctx()) -> ctx().
route(_, [], Ctx) -> Ctx;
route(Module, Events, #{skctx := SinkCtx}=Ctx) ->
  case stepflow_sink:process(Events, SinkCtx) of
    {ok, SinkCtx2} ->
      % events processed!
      Module:ack(Ctx#{skctx => SinkCtx2});
    {error, _} ->
      % something goes wrong! Leave memory as it is.
      Module:nack(Ctx)
  end.

-spec debug(pid(), atom(), integer(), pid()) -> ok.
debug(PidChannel, Type, Period, Pid) ->
  erlang:start_timer(10, PidChannel, {debug, {Type, Period, Pid}}).

%% API for behaviour implementations


handle_call({connect_sink, SinkCtx}, _From, Ctx) ->
  {reply, ok, Ctx#{skctx => SinkCtx}};
handle_call(Msg, _From, Ctx) ->
  warning("handle_call", Msg),
  {reply, Msg, Ctx}.

handle_info({timeout, _, {debug, {info, 0, Pid}}}, Ctx) ->
  Pid ! get_info(Ctx),
  {noreply, Ctx};
handle_info({timeout, _, {debug, {info, Period, Pid}}=Cfg}, Ctx) ->
  Pid ! get_info(Ctx),
  erlang:start_timer(Period, self(), Cfg),
  {noreply, Ctx};
handle_info(Msg, Ctx) ->
  warning("handle_info", Msg),
  {noreply, Ctx}.

handle_cast(Msg, Ctx) ->
  warning("handle_cast", Msg),
  {noreply, Ctx}.

%% Private functions

warning(Fun, Msg) ->
  error_logger:warning_msg(
    "[Channel][~s] ~p message not processed: ~p~n", [Fun, self(), Msg]).

get_info(Ctx) -> Ctx.
