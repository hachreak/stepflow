%%%-------------------------------------------------------------------
%% @doc stepflow source message
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_source_message).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_source).
-behaviour(gen_server).

-export([
  append/2,
  setup_channels/2
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

-spec append(pid(), event() | list(event())) -> ok.
append(Pid, Events) when is_list(Events) ->
  gen_server:call(Pid, {append, Events});
append(Pid, Event) -> append(Pid, [Event]).

%% Callbacks

setup_channels(PidS, PidCs) ->
  gen_server:call(PidS, {setup, channels, PidCs}).

%% Callbacks gen_server

-spec start_link(ctx()) -> {ok, pid()} | ignore | {error, term()}.
start_link(Config) ->
  gen_server:start_link(?MODULE, [Config], []).

-spec init(list(ctx())) -> {ok, ctx()}.
init([{ItCtxs, Config}]) ->
  {ok, SrcCtx} = stepflow_source:init(ItCtxs),
  {ok, Config#{source => SrcCtx}}.

-spec handle_call({setup, channels, list(pid())} |
                  {append, list(event())}, {pid(), term()}, ctx()) ->
    {reply, ok, ctx()}.
handle_call({setup, channels, PidCs}, _From, #{source := SrcCtx}=Ctx) ->
  SrcCtx2 = stepflow_source:setup(PidCs, SrcCtx),
  {reply, ok, Ctx#{source => SrcCtx2}};
handle_call({append, Events}, _From, #{source := SrcCtx}=Ctx) ->
  {ok, SrcCtx2} = stepflow_source:append(Events, SrcCtx),
  {reply, ok, Ctx#{source := SrcCtx2}};
handle_call(Msg, From, Ctx) ->
  stepflow_source:handle_call(Msg, From, Ctx).

% -spec handle_cast({append, list(event())}, ctx()) -> {noreply, ctx()}.
handle_cast(Msg, Ctx) -> stepflow_source:handle_cast(Msg, Ctx).

handle_info(Msg, Ctx) -> stepflow_source:handle_info(Msg, Ctx).

terminate(_Reason, _Ctx) ->
  io:format("Terminate!!~n"),
  ok.

code_change(_OldVsn, Ctx, _Extra) ->
  io:format("code changed !"),
  {ok, Ctx}.
