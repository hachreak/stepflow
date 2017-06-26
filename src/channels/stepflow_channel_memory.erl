%%%-------------------------------------------------------------------
%% @doc stepflow channel memory
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_channel_memory).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_channel).

-export([
  handle_append/2,
  handle_has_more/1,
  handle_init/1,
  handle_pop/3
]).

-type ctx()   :: list().
-type event() :: stepflow_channel:event().
-type skctx() :: stepflow_channel:skctx().

-spec handle_init(ctx()) -> {ok, ctx()} | {error, term()}.
handle_init(_) -> {ok, []}.

-spec handle_append(event(), ctx()) -> {ok, ctx()} | {error, term()}.
handle_append(Event, Ctx) -> {ok, [Event | Ctx]}.

% FIXME how to empty the buffer if errors happen on sink?
-spec handle_pop(fun(), skctx(), ctx()) ->
    {ok, skctx(), ctx()} | {error, term()}.
handle_pop(Fun, SinkCtx, Memory) ->
  io:format("~nmemory: ~p~n~n~n", [Memory]),
  Event = lists:last(Memory),
  % get event
  % execute the fun (e.g. move to anothe channel)
  case Fun(Event, SinkCtx) of
    {ok, SinkCtx2} ->
      % ack received, I can remove the event from memory
      {ok, SinkCtx2, lists:droplast(Memory)};
    {error, _} ->
      % something goes wrong! Leave memory as it is.
      {error, Memory}
  end.

-spec handle_has_more(ctx()) -> {boolean(), ctx()}.
handle_has_more(Memory) -> {erlang:length(Memory) > 0, Memory}.
