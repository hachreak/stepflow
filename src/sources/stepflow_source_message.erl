%%%-------------------------------------------------------------------
%% @doc stepflow source message
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_source_message).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_source).

-export([
  append/2
]).

-export([
  init/1,
  handle_call/3,
  handle_cast/2
]).

% -type ctx()   :: stepflow_source:ctx().
% -type event() :: stepflow_event:event().

%% API

append(Pid, Events) ->
  stepflow_source:append(Pid, Events).

%% Callbacks

init(Config) ->
  {ok, Config}.

handle_call(_Msg, _From, Ctx) ->
  {reply, not_implemented, Ctx}.

handle_cast(Msg, Ctx) ->
  error_logger:warning_msg("[Source] not implemented for message ~p~n", [Msg]),
  {noreply, Ctx}.
