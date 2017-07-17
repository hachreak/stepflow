%%%-------------------------------------------------------------------
%% @doc stepflow encoder
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_encoder).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-type event() :: stepflow_event:event().

%% Callbacks

-callback encode(event()) -> binary().

-callback decode(binary()) -> event().
