%%%-------------------------------------------------------------------
%% @doc steflow top level agent supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_agent_sup).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(supervisor).

%% API
-export([start_link/1]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link(FlowConfigs) ->
  supervisor:start_link({local, ?SERVER}, ?MODULE, [FlowConfigs]).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([FlowConfigs]) ->
  Children = [
    {stepflow_agent,
     {stepflow_agent, start_link, [FlowConfigs]},
     permanent, 1000, worker, [stepflow_agent]
    }
  ],
  {ok, { {one_for_all, 0, 1}, Children} }.

%%====================================================================
%% Internal functions
%%====================================================================
