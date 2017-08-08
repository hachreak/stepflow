Terminals
  source_op sink_op interceptor_op channel_op eol_op
  flow_op to_op colon_op eos_op erlang_op comma_op
  field eq_op map_op sbo_op sbc_op.

Nonterminals
  grammar var interceptors flow flow_defs flow_def var_mdef var_def
  expression.

Rootsymbol grammar.

grammar -> expression : ['$1'].
grammar -> expression grammar : to_list('$1', '$2').

expression -> var : '$1'.
expression -> flow : '$1'.
expression -> erlang_op : {'erlang', to_code('$1')}.

flow -> flow_op field colon_op field flow_defs :
    {unwrap('$1'), {flow_name('$2'), {flow_name('$4'), '$5'}}}.

flow_defs -> flow_def eol_op : ['$1'].
flow_defs -> flow_def eos_op flow_defs : to_list('$1', '$3').

flow_def -> to_op field to_op field : {flow_name('$2'), flow_name('$4')}.
flow_def -> to_op field : {flow_name('$2'), none}.

var -> interceptor_op var_def : build_var('$1', '$2').
var -> channel_op var_def : build_var('$1', '$2').
var -> source_op var_mdef : build_var('$1', '$2').
var -> sink_op var_mdef : build_var('$1', '$2').

var_def -> field eq_op field map_op eol_op : {'$1', bind('$3', '$4')}.

var_mdef -> field eq_op field sbo_op sbc_op map_op eol_op :
    {'$1', bind('$3', [], '$6')}.
var_mdef -> field eq_op field sbo_op interceptors sbc_op map_op eol_op :
    {'$1', bind('$3', '$5', '$7')}.

interceptors -> field : [to_var('$1')].
interceptors -> field comma_op interceptors :
    to_list(to_var('$1'), to_list(reserved(','), '$3')).

Erlang code.

build_var({_, _, interceptor}, {Name, Value}) ->
  {interceptor,
   to_squeeze([[to_var(Name), reserved('=')], Value, [reserved(dot)]])};
build_var(Type, {Name, Value}) ->
  {unwrap(Type), to_squeeze([
    [to_var(Name), reserved('='), reserved('{'), to_atom(Type),
     reserved(',')],
    Value,
    [reserved('}'), reserved(dot)]
  ])}.

to_list(A, Rest) when is_list(Rest) -> [A | Rest];
to_list(A, B) -> [A, B].

unwrap({_,V})   -> V;
unwrap({_,_,V}) -> V;
unwrap(V) -> V.

bind(Module, [Vars], Config) ->
  bind(Module, Vars, Config);
bind(Module, Vars, Config) ->
  to_squeeze([
    reserved('{'), to_atom(Module),
    reserved(','), reserved('{'),
      reserved('['), Vars, reserved(']'), reserved(','), to_code(Config),
    reserved('}'), reserved('}')
  ]).
bind(Module, Config) ->
  to_squeeze([
    reserved('{'), to_atom(Module),
    reserved(','), to_code(Config), reserved('}')
  ]).

to_squeeze(Vars) ->
  lists:foldr(fun(List, Acc) ->
    case is_list(List) of
      true -> List ++ Acc;
      false -> [List | Acc]
    end
  end, [], Vars).

to_var(Var) -> atom_name(rename_field(Var, var)).
to_atom(Var) -> atom_name(rename_field(Var, atom)).
to_code({_, _, Var}) ->
  {ok, Res, _} = erl_scan:string(Var),
  Res.

rename_field({_, A, B}, C) -> {C, A, B}.

flow_name(A) -> unwrap(atom_name(A)).

reserved({_, A, B}) -> {B, A};
reserved(A) -> {A, 1}.

atom_name({A, B, Atom}) when is_atom(Atom) -> {A, B, Atom};
atom_name({A, B, String}) -> {A, B, list_to_atom(String)}.
