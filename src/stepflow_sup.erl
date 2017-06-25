%%%-------------------------------------------------------------------
%% @doc stepflow top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_sup).

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
    {stepflow_agent_sup,
     {stepflow_agent_sup, start_link, [[]]},
     permanent, 1000, supervisor, [stepflow_agent_sup]
    }
  ],
  {ok, { {one_for_all, 0, 1}, Children} }.

%%====================================================================
%% Internal functions
%%====================================================================
