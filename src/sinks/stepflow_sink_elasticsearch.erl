-module(stepflow_sink_elasticsearch).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_sink).

-include_lib("erlastic_search/include/erlastic_search.hrl").

-export([
  handle_init/1,
  handle_process/2
]).

-type event() :: stepflow_event:event().
-type ctx()   :: stepflow_sink:ctx().

-spec handle_init(ctx()) -> {ok, ctx()} | {error, term()}.
handle_init(#{}=Config) ->
  application:ensure_all_started(erlastic_search),
  Host = maps:get(host, Config, <<"localhost">>),
  Port = maps:get(port, Config, 9200),
  Index = maps:get(index, Config, <<"stepflow_sink_elasticsearch">>),
  % Mapping = maps:get(mappings, Config),
  Params = #erls_params{host=Host, port=Port},
  maybe_create_index(Index, Params),
  {ok, #{params => Params, index => Index}}.

-spec handle_process(list(event()), ctx()) -> {ok, ctx()} | {error, term()}.
handle_process(Events, #{params := Params, index := Index}=Ctx) ->
  io:format("Events indexed: ~p~n", [Events]),
  Type = <<"events">>,
  ToIndex = [{Index, Type, undefined, Event} || Event <- Events],
  case erlastic_search:bulk_index_docs(Params, ToIndex) of
    {ok, _} -> {ok, Ctx};
    {error, _} -> {error, es_index_error}
  end.

%% Private functions

maybe_create_index(Index, Params) ->
  erlastic_search:create_index(Params, Index).
