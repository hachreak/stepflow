%%%-------------------------------------------------------------------
%% @doc stepflow sink
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_sink).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-type event() :: stepflow_agent:event().
-type ctx()   :: any().

-callback process(event(), ctx()) -> ok.
