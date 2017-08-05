Definitions.

LETTER = [a-zA-Z_0-9]
WORD = LETTER+
WHITESPACE = [\s\t\n\r]
ANY = [\"\s\n\t\r\ca-zA-Z_0-9\-\=\>\,\<]
ERLANG = [^`]

Rules.

{WHITESPACE}+ : skip_token.
channel : {token, {channel_op, TokenLine, list_to_atom(TokenChars)}}.
% define : {token, {define_op, TokenLine, list_to_atom(TokenChars)}}.
flow : {token, {flow_op, TokenLine, list_to_atom(TokenChars)}}.
% from : {token, {from_op, TokenLine, list_to_atom(TokenChars)}}.
interceptor : {token, {interceptor_op, TokenLine, list_to_atom(TokenChars)}}.
sink : {token, {sink_op, TokenLine, list_to_atom(TokenChars)}}.
source : {token, {source_op, TokenLine, list_to_atom(TokenChars)}}.
\= : {token, {eq_op, TokenLine, list_to_atom(TokenChars)}}.
{LETTER}+ : {token, {field, TokenLine, TokenChars}}.
\[ : {token, {sbo_op, TokenLine, list_to_atom(TokenChars)}}.
\] : {token, {sbc_op, TokenLine, list_to_atom(TokenChars)}}.
\#\{{ANY}*\} : {token, {map_op, TokenLine, TokenChars}}.
% \#\{ : {token, {cbo_op, TokenLine, list_to_atom(TokenChars)}}.
% \} : {token, {cbc_op, TokenLine, list_to_atom(TokenChars)}}.
% \=\> : {token, {map_to_op, TokenLine, list_to_atom(TokenChars)}}.
\|\> : {token, {to_op, TokenLine, list_to_atom(TokenChars)}}.
\, : {token, {comma_op, TokenLine, list_to_atom(TokenChars)}}.
\;\n : {token, {eos_op, TokenLine, list_to_atom(TokenChars)}}.
\.\n : {token, {eol_op, TokenLine, list_to_atom(TokenChars)}}.
\: : {token, {colon_op, TokenLine, list_to_atom(TokenChars)}}.
\<\<\<{ERLANG}+\>\>\> : {token, {erlang_op, TokenLine, remove_header(TokenChars)}}.
[.]+ : {error, syntax}.

Erlang code.

remove_header(Str) ->
  Sub = lists:nthtail(length("<<<\n"), Str),
  {Body, _} = lists:split(length(Sub) - length("\n>>>"), Sub),
  Body.
  % Str.
