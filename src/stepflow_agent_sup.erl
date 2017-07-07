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
  supervisor:start_link(?MODULE, []).

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
  % FIXME find a way to alert everybody that
  % the pid of the gen_server is changed!
  {ok, { {simple_one_for_one, 10, 5}, Children} }.

%%====================================================================
%% Internal functions
%%====================================================================
