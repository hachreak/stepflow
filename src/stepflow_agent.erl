%%%-------------------------------------------------------------------
%% @doc stepflow agent
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_agent).

-behaviour(gen_server).

-export([
  start_link/0
]).

%% Callbacks
-export([
  init/1,
  code_change/3,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2
]).

-record(state, {}).

%%====================================================================
%% API
%%====================================================================

start_link() ->
  gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Callbacks

init([]) ->
  process_flag(trap_exit, true),
  {ok, #state{}}.

handle_call(_Request, _From, Ctx) ->
  {reply, hello, Ctx}.

handle_cast(_Request, Ctx) ->
  {noreply, Ctx}.

handle_info(_Info, Ctx) ->
  {noreply, Ctx}.

terminate(_Reason, _Ctx) ->
  ok.

code_change(_OldVsn, Ctx, _Extra) ->
  {ok, Ctx}.

%%====================================================================
%% Internal functions
%%====================================================================
