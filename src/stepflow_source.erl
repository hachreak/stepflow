%%%-------------------------------------------------------------------
%% @doc stepflow source
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_source).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  append/3,
  config/1,
  debug/4,
  setup_channel/2
]).

-export([
  handle_cast/2,
  handle_info/2
]).

-type ctx()   :: map().
-type event() :: stepflow_event:event().
-type inctx() :: stepflow_interceptor:ctx().

%% API

-spec config({list({atom(), inctx()}), ctx()}) ->
    {ok, ctx()} | {error, term()}.
config({InterceptorsConfig, Ctx}) ->
  InCtxs = stepflow_interceptor:init_all(InterceptorsConfig),
  {ok, Ctx#{inctxs => InCtxs}}.

-spec setup_channel(pid(), pid()) -> ok | {error, term()}.
setup_channel(Pid, ChPid) -> gen_server:call(Pid, {setup_channel, ChPid}).

-spec append(list(pid()), list(event()), list(inctx())) -> {ok, list(inctx())}.
append(PidChs, Events, InCtxs) ->
  case stepflow_interceptor:transform(Events, InCtxs) of
    {ok, Event2, InCtxs2} ->
      lists:foreach(fun(PidCh) ->
          % TODO check message is successfully stored in channel
          ok = stepflow_channel:append(PidCh, Event2)
        end, PidChs),
      {ok, InCtxs2};
    {reject, InCtxs2} -> {ok, InCtxs2}
    % TODO {stop, Events, InCtxs}
    % TODO {error, _}
  end.

-spec debug(pid(), atom(), integer(), pid()) -> ok.
debug(PidSource, Type, Period, Pid) ->
  erlang:start_timer(10, PidSource, {debug, {Type, Period, Pid}}).

%% API for behaviour implementations

handle_cast(Msg, Ctx) ->
  error_logger:warning_msg("[Source] message not processed: ~p~n", [Msg]),
  {noreply, Ctx}.

handle_info({timeout, _, {debug, {channels, _, Pid}}}, Ctx) ->
  Pid ! get_channels(Ctx),
  {noreply, Ctx};
handle_info({timeout, _, {debug, {info, 0, Pid}}}, Ctx) ->
  Pid ! get_info(Ctx),
  {noreply, Ctx};
handle_info({timeout, _, {debug, {info, Period, Pid}}=Cfg}, Ctx) ->
  Pid ! get_info(Ctx),
  erlang:start_timer(Period, self(), Cfg),
  {noreply, Ctx};
handle_info(Msg, Ctx) ->
  error_logger:warning_msg("[Source] message not processed: ~p~n", [Msg]),
  {noreply, Ctx}.

%% Private functions

get_info(Ctx) -> Ctx.

get_channels(#{channels := ChPids}) ->
  ChPids.
