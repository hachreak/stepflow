%%%-------------------------------------------------------------------
%% @doc stepflow sink message: send the event as a message to another agent.
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_sink_message).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_sink).

-export([
  handle_init/1,
  handle_is_module/2,
  handle_process/2
]).

-type event() :: stepflow_sink:event().
-type ctx()   :: stepflow_sink:ctx().

-spec handle_init(ctx()) -> {ok, ctx()} | {error, term()}.
handle_init(Pid) -> {ok, Pid}.

-spec handle_process(event(), ctx()) -> {ok, ctx()}.
handle_process(Event, Pid) ->
  case stepflow_source_message:sync_append(Pid, Event) of
    ok ->
      io:format("Event send to ~p: ~p~n", [Pid, Event]),
      {ok, Pid};
    _ -> {error, source_unreachable}
  end.

-spec handle_is_module(erlang:pid(), ctx()) -> boolean().
handle_is_module(Pid, Pid) -> true;
handle_is_module(_, _) -> false.
