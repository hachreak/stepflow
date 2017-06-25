%%%-------------------------------------------------------------------
%% @doc steflow top level agent supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_agent_sup).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link() ->
  supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([]) ->
  Children = [
    {stepflow_agent,
     {stepflow_agent, start_link, []},
     transient, 1000, worker, [stepflow_agent]
    }
  ],
  {ok, { {simple_one_for_one, 0, 1}, Children} }.

%%====================================================================
%% Internal functions
%%====================================================================
