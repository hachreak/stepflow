%%%-------------------------------------------------------------------
%% @doc stepflow channel memory
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_channel_memory).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_channel).

-export([
  handle_append/2,
  handle_init/1,
  handle_pop/2
]).

handle_init(_) -> {ok, []}.

handle_append(Event, Ctx) -> {ok, [Event | Ctx]}.

handle_pop(Fun, [Event | Ctx]=Memory) ->
  io:format("~nmemory: ~p~n~n~n", [Memory]),
  % get event
  % execute the fun (e.g. move to anothe channel)
  case Fun(Event) of
    {ok, SinkCtx} ->
      % ack received, I can remove the event from memory
      {ok, SinkCtx, Ctx};
    {error, SinkCtx, _} ->
      % something goes wrong! Leave memory as it is.
      {ok, SinkCtx, Memory}
  end.
