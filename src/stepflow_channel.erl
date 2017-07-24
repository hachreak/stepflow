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
  pop/1,
  route/3
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
-callback ack(ctx()) -> {ok, ctx()}.

% @end Called in case the event has NOT been processed successfully.
% @end
-callback nack(ctx()) -> {ok, ctx()}.

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

-spec route(atom(), list(event()), ctx()) ->
    {ok, ctx()} | {error, term()}.
route(_, [], Ctx) -> {ok, Ctx};
route(Module, Events, #{skctx := SinkCtx}=Ctx) ->
  case stepflow_sink:process(Events, SinkCtx) of
    {ok, SinkCtx2} -> Module:ack(Ctx#{skctx => SinkCtx2});
    {error, _} ->
      % something goes wrong! Leave memory as it is.
      Module:nack(Ctx),
      % ok = amqp_channel:cast(Channel, #'basic.nack'{delivery_tag = Tag}),
      {error, sink_fails}
  end.
