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
  pop/1
]).

-export_type([event/0]).

-type ctx()   :: any().
-type event() :: #{headers => map(), body => map()}.
-type skctx() :: stepflow_sink:ctx().

%% Callbacks

-callback config(ctx()) -> {ok, ctx()}  | {error, term()}.

%%====================================================================
%% API
%%====================================================================

-spec connect_sink(pid(), skctx()) -> ok.
connect_sink(Pid, SinkCtx) -> gen_server:call(Pid, {connect_sink, SinkCtx}).

-spec setup(pid()) -> ok.
setup(Pid) -> gen_server:call(Pid, setup).

-spec pop(pid()) -> ok.
pop(Pid) -> gen_server:cast(Pid, pop).

-spec append(pid(), event()) -> ok.
append(Pid, Event) -> gen_server:cast(Pid, {append, Event}).
