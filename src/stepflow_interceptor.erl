%%%-------------------------------------------------------------------
%% @doc stepflow interceptor
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_interceptor).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-type event() :: stepflow_agent:event().
-type ctx()   :: any().

-callback intercept(event(), ctx()) -> ok.
