%%%-------------------------------------------------------------------
%% @doc stepflow source message
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_source_message).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

% -behaviour(stepflow_source).
-behaviour(gen_server).

-export([
  append/2,
  sync_append/2
]).

-export([
  start_link/1,
  init/1,
  code_change/3,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2
]).

-type ctx()   :: stepflow_source:ctx().
-type event() :: stepflow_event:event().

%% API

-spec sync_append(pid(), event()) -> ok | {noproc, any()}.
sync_append(Pid, Event) ->
  gen_server:call(Pid, {append, Event}).

-spec append(pid(), event()) -> ok.
append(Pid, Event) ->
  gen_server:cast(Pid, {append, Event}).

%% Callbacks gen_server

-spec start_link(ctx()) -> {ok, pid()} | ignore | {error, term()}.
start_link(Config) ->
  gen_server:start_link(?MODULE, [Config], []).

-spec init(list(ctx())) -> {ok, ctx()}.
init([Config]) -> {ok, Config#{channels => []}}.

-spec handle_call({setup_channel, pid()}, {pid(), term()}, ctx()) ->
    {reply, ok, ctx()}.
handle_call({setup_channel, ChPid}, _From, #{channels := Channels}=Ctx) ->
  {reply, ok, Ctx#{channels => [ChPid | Channels]}};
handle_call({append, Event}, _From,
            #{inctxs := InCtxs, channels := ChPids}=Ctx) ->
  {ok, InCtxs2} = stepflow_source:append(ChPids, Event, InCtxs),
  {reply, ok, Ctx#{inctxs := InCtxs2}};
handle_call(Input, _From, Ctx) ->
  {reply, Input, Ctx}.

-spec handle_cast({append, event()}, ctx()) -> {noreply, ctx()}.
handle_cast({append, Event}, #{inctxs := InCtxs, channels := ChPids}=Ctx) ->
  {ok, InCtxs2} = stepflow_source:append(ChPids, Event, InCtxs),
  {noreply, Ctx#{inctxs := InCtxs2}};
handle_cast(_, Ctx) ->
  {noreply, Ctx}.

handle_info(_Info, Ctx) ->
  {noreply, Ctx}.

terminate(_Reason, _Ctx) ->
  io:format("Terminate!!~n"),
  ok.

code_change(_OldVsn, Ctx, _Extra) ->
  io:format("code changed !"),
  {ok, Ctx}.
