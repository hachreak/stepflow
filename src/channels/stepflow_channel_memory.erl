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

handle_pop(Fun, [Event | Ctx]) ->
  % get event
  % execute the fun (e.g. move to anothe channel)
  {ok, SinkCtx} = Fun(Event),
  % ack the channel
  % return
  {ok, SinkCtx, Ctx}.
