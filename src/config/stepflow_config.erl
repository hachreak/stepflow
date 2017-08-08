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
    fun(TokensParsed, Acc) ->
      compile(TokensParsed, Acc)
    end, {[], []}, AllTokensParsed),
  Result.

run(String) -> eval(load(String)).

%% Private functions

compile({Type, TokensParsed}, {Result, Bindings})
    when Type =:= source orelse Type =:= channel orelse Type =:= sink
         orelse Type =:= interceptor orelse Type =:= erlang ->
  NewBindings = parse_expr(TokensParsed, Bindings),
  {Result, NewBindings};
compile({flow, {Name, {First, Second}}}, {Result, Bindings}) ->
  {Input, Output} = case get(First, Bindings) of
    {source, Input2Ret} ->
      Output2Ret = lists:map(fun({ChannelName, SinkName}) ->
          {get_binded(channel, ChannelName, Bindings),
           get_binded_or_none(sink, SinkName, Bindings)}
        end, Second),
      {Input2Ret, Output2Ret};
    {channel, ChannelOutput} ->
      [{SinkName, _}] = Second,
      SinkOutput = get_binded(sink, SinkName, Bindings),
      Output2Ret = [{ChannelOutput, SinkOutput}],
      {none, Output2Ret};
    {_, _} -> throw({wrong_type, {expected, [source, channel], First}})
  end,
  Pids = stepflow_agent_sup:new(Input, Output),
  {_, PidSource, _} =  Pids,
  {[{Name, Pids} | Result], [{Name, PidSource}  | Bindings]};
compile(ToCompile, Acc) ->
  io:format("[Warning] Skip: ~p~n", [ToCompile]),
  Acc.

parse_expr(TokensParsed, Bindings) ->
  {ok, [Form]} = erl_parse:parse_exprs(TokensParsed),
  {_, _, NewBindings} = erl_eval:expr(Form, Bindings),
  NewBindings.

get_binded_or_none(Type, Name, Bindings) ->
  case value(Name, Bindings) of
    {Type, Value} -> Value;
    none -> none;
    _ -> throw({wrong_type, {expected, [Type], Name}})
  end.

get_binded(Type, Name, Bindings) ->
  case value(Name, Bindings) of
    {Type, Value} -> Value;
    _ -> throw({wrong_type, {expected, [Type], Name}})
  end.

get(Name, Bindings) ->
  case value(Name, Bindings) of
    {Type, _}=Value -> Value;
    _ -> throw({var_unknown, Name})
  end.

value(none, _) -> none;
value(Key, PropLists) -> proplists:get_value(Key, PropLists).
