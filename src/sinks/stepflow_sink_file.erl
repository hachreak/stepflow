%%%-------------------------------------------------------------------
%% @doc stepflow sink: write to file.
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_sink_file).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_sink).

-export([
  handle_init/1,
  handle_process/2
]).

-type event() :: stepflow_event:event().
-type ctx()   :: stepflow_sink:ctx().

-spec handle_init(ctx()) -> {ok, ctx()} | {error, term()}.
handle_init(#{filename := Filename}=Ctx) ->
  {ok, File} = file:open(Filename, [write]),
  {ok, Ctx#{file => File}}.

-spec handle_process(list(event()), ctx()) -> {ok, ctx()} | {error, term()}.
handle_process(Events, #{file := File}=Ctx) ->
  file:write(File, [stepflow_event:body(Event) || Event <- Events]),
  {ok, Ctx}.
