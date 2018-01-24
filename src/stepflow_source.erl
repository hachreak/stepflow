%%%-------------------------------------------------------------------
%% @doc stepflow source
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_source).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(gen_server).

-export([
  append/2
%   init/1,
%   setup/2
]).

-export([
  code_change/3,
  handle_call/3,
  handle_cast/2,
  init/1,
  start_link/1,
  terminate/2
]).

-type ctx()   :: map().
-type inctx() :: stepflow_interceptor:ctx().

% Callbacks

% -callback init(list({list(inctx()), ctx()})) -> {ok, ctx()}.
-callback init({{atom(), map()}, inctx()}) -> {ok, ctx()}.

-callback handle_call(any(), any(), ctx()) -> {any(), any(), ctx()}.

-callback handle_cast(any(), ctx()) -> {any(), ctx()}.

%% API

append(Pid, Events) ->
  gen_server:cast(Pid, {append, Events}).

%% Callbacks gen_server

% -spec start_link(ctx()) -> {ok, pid()} | ignore | {error, term()}.
start_link(InConfig) ->
  gen_server:start_link(?MODULE, [InConfig], []).

init([{{Module, Config}, InConfig, PidCs}]) ->
  {ok, SrcCtx} = Module:init(Config),
  InCtxs = stepflow_interceptor:init_all(InConfig),
  Ctx = set_channels(PidCs, #{src => {Module, SrcCtx}, inctxs => InCtxs}),
  {ok, Ctx}.

handle_call({setup, channels, PidCs}, _From, Ctx) ->
  {reply, ok, set_channels(PidCs, Ctx)};

handle_call(Msg, From, #{src := {Module, SrcCtx}}=Ctx) ->
  {Reply, Msg2, SrcCtx2} = Module:handle_call(Msg, From, SrcCtx),
  {Reply, Msg2, Ctx#{src => {Module, SrcCtx2}}}.

handle_cast({append, Events}, Ctx) ->
  {ok, Ctx2} = do_append(Events, Ctx),
  {noreply, Ctx2};

handle_cast(Msg, #{src := {Module, SrcCtx}}=Ctx) ->
  {Reply, SrcCtx2} = Module:handle_cast(Msg, SrcCtx),
  {Reply, Ctx#{src => {Module, SrcCtx2}}}.

terminate(_Reason, _Ctx) ->
  io:format("Terminate!!~n"),
  ok.

code_change(_OldVsn, Ctx, _Extra) ->
  io:format("code changed !"),
  {ok, Ctx}.

%%%

set_channels([], Ctx) -> Ctx;
set_channels(PidCs, Ctx) ->
  Ctx#{channels => PidCs}.

do_append(Events, #{inctxs := InCtxs, channels := ChPids}=Ctx) ->
  {ok, NewInCtxs} =
    case stepflow_interceptor:transform(Events, InCtxs) of
      {ok, Event2Send, InCtxs2} ->
        lists:foreach(fun(PidCh) ->
            % TODO check message is successfully stored in channel
            ok = stepflow_channel:append(PidCh, Event2Send)
          end, ChPids),
        {ok, InCtxs2};
      {reject, InCtxs2} -> {ok, InCtxs2}
      % TODO {stop, Events, InCtxs}
      % TODO {error, _}
    end,
  {ok, Ctx#{inctxs => NewInCtxs}}.
