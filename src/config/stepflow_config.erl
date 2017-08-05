%%%-------------------------------------------------------------------
%% @doc stepflow config
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_config).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  eval/1,
  load/1,
  run/1
]).

load(String) ->
  {ok, Tokens, _} = stepflow_config_lexer:string(String),
  {ok, AllTokensParsed} = stepflow_config_parser:parse(Tokens),
  AllTokensParsed.

% link
eval(AllTokensParsed) ->
  {Result, _} = lists:foldl(
    fun({Type, TokensParsed}, Acc) ->
      compile(Type, TokensParsed, Acc)
    end, {[], []}, AllTokensParsed),
  Result.

run(String) -> eval(load(String)).

%% Private functions

compile(Type, TokensParsed, {Result, Bindings})
    when Type =:= interceptor orelse Type =:= source orelse Type =:= channel
         orelse Type =:= sink orelse Type =:= erlang->
  NewBindings = new_bind(TokensParsed, Bindings),
  {Result, NewBindings};
compile(flow, {Name, {Source, ChannelSinks}}, {Result, Bindings}) ->
  Input = value(Source, Bindings),
  Output = [{value(Channel, Bindings), value(Sink, Bindings)}
            || {Channel, Sink} <- ChannelSinks],
  Pids = stepflow_agent_sup:new(Input, Output),
  {_, PidSource, _} =  Pids,
  {[{Name, Pids} | Result], [{Name, PidSource}  | Bindings]};
compile(_, _, Acc) ->
  Acc.

new_bind(TokensParsed, Bindings) ->
  {ok, [Form]} = erl_parse:parse_exprs(TokensParsed),
  {_, _, NewBindings} = erl_eval:expr(Form, Bindings),
  NewBindings.

value(Key, PropLists) -> proplists:get_value(Key, PropLists).
