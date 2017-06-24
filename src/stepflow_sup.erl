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
  {ok, Flows} = application:get_env(stepflow, flows),

  FlowConfigs = config(Flows),

  Children = [
    {stepflow_agent_sup,
     {stepflow_agent_sup, start_link, [FlowConfigs]},
     permanent, 1000, supervisor, [stepflow_agent_sup]
    }
  ],
  {ok, { {one_for_all, 0, 1}, Children} }.

%%====================================================================
%% Internal functions
%%====================================================================

-spec config(list()) -> list().
config(Flows) ->
  lists:map(fun({InterceptorsConfig, ChannelConfig, SinkConfig}) ->
      {config_interceptors(InterceptorsConfig),
       config_channel(ChannelConfig),
       config_sink(SinkConfig)}
    end, Flows).

-spec config_channel({atom(), any()}) -> stepflow_channel:ctx().
config_channel({Channel, Config}) ->
  {ok, ChannelCtx} = stepflow_channel:init(Channel, Config),
  ChannelCtx.

-spec config_interceptors(list({atom(), any()})) -> stepflow_interceptor:ctx().
config_interceptors(InterceptorsConfig) ->
  lists:map(fun({Intercaptor, Config}) ->
      {Intercaptor, Config}
    end, InterceptorsConfig).

-spec config_sink({atom(), any()}) -> stepflow_sink:ctx().
config_sink({Sink, Config}) ->
  {ok, SinkCtx} = stepflow_sink:init(Sink, Config),
  SinkCtx.
