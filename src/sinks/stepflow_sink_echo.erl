%%%-------------------------------------------------------------------
%% @doc stepflow sink echo
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_sink_echo).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_sink).

-export([
  %init/1,
  process/2
]).

-type event() :: stepflow_sink:event().
-type ctx()   :: stepflow_sink:ctx().

-spec process(event(), ctx()) -> ok.
process(Event, _Ctx) ->
  io:format("Event received: ~n~p~n~n", [Event]).
