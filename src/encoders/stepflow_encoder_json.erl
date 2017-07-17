%%%-------------------------------------------------------------------
%% @doc stepflow encoder json
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_encoder_json).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  encode/1,
  decode/1
]).

-type event() :: stepflow_event:event().

%% Callbacks

-spec encode(event()) -> binary().
encode(Event) -> jsx:encode(Event).

-spec decode(binary()) -> event().
decode(Binary) -> jsx:decode(Binary, [return_maps]).
