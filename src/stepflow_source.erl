%%%-------------------------------------------------------------------
%% @doc stepflow source
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_source).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  append/2,
  init/1,
  setup/2
]).

-type ctx()   :: map().
-type inctx() :: stepflow_interceptor:ctx().

% Callbacks

% -callback init(list({list(inctx()), ctx()})) -> {ok, ctx()}.

-callback setup_channels(pid(), list(pid())) -> ok.

%% API

init(InterceptorsConfig) ->
  InCtxs = stepflow_interceptor:init_all(InterceptorsConfig),
  {ok, #{inctxs => InCtxs}}.

setup(ChPids, Ctx) -> Ctx#{channels => ChPids}.

append(Events, #{inctxs := InCtxs, channels := ChPids}=Ctx) ->
  {ok, NewInCtxs} =
    case stepflow_interceptor:transform(Events, InCtxs) of
      {ok, Event2Send, InCtxs2} ->
        lists:foreach(fun(PidCh) ->
            % TODO check message is successfully stored in channel
            ok = stepflow_channel:append(PidCh, Event2Send)
          end, ChPids),
        {ok, InCtxs2};
      {reject, InCtxs2} -> {ok, InCtxs2}
      % TODO {stop, Events, InCtxs}
      % TODO {error, _}
    end,
  {ok, Ctx#{inctxs => NewInCtxs}}.
