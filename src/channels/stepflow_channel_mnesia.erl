%%%-------------------------------------------------------------------
%% @doc stepflow channel mnesia
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_channel_mnesia).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_channel).
-behaviour(gen_server).

-include_lib("stdlib/include/qlc.hrl").

-export([
  start_link/1,
  init/1,
  code_change/3,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  terminate/2
]).

-export([
  ack/1,
  nack/1,
  update_chctx/2
]).

-type ctx()   :: map().
-type event() :: stepflow_event:event().

-record(stepflow_channel_mnesia_events, {timestamp, events}).

%% Callbacks channel

-spec ack(ctx()) -> ctx().
ack(#{timestamps := Timestamps, table := Table}=Ctx) ->
  % TODO improve deleting all in one time!
  [mnesia:delete({Table, Timestamp}) || Timestamp <- Timestamps],
  maps:remove(timestamps, Ctx).

-spec nack(ctx()) -> ctx().
nack(Ctx)-> maps:remove(timestamps, Ctx).

update_chctx(Ctx, ChCtx) -> Ctx#{chctx => ChCtx}.

%% Callbacks gen_server

-spec start_link(ctx()) -> {ok, pid()} | ignore | {error, term()}.
start_link(Config) ->
  gen_server:start_link(?MODULE, [Config], []).

-spec init(list(ctx())) -> {ok, ctx()}.
init([{SkCtx, Config}]) ->
  Config2 = case stepflow_channel:init(SkCtx) of
    {ok, ChCtx} -> update_chctx(Config, ChCtx);
    no_sink -> Config
  end,
  {ok, Ctx} = config(Config2),
  create_schema(),
  create_table(Ctx),
  io:format("init: ~p~n~n", [Ctx]),
  {ok, flush(Ctx)}.

-spec handle_call(any(), {pid(), term()}, ctx()) -> {reply, ok, ctx()}.
handle_call(debug, _From, Ctx) ->
  {reply, Ctx, Ctx};
handle_call(Msg, From, Ctx) ->
  stepflow_channel:handle_call(Msg, From, Ctx).

-spec handle_cast({append, list(event())} | pop, ctx()) -> {noreply, ctx()}.
handle_cast({append, Events}, Ctx) ->
  {noreply, append(Events, Ctx)};
handle_cast(pop, Ctx) ->
  {noreply, transactional_pop(Ctx)};
handle_cast(Msg, Ctx) -> stepflow_channel:handle_cast(Msg, Ctx).

handle_info({timeout, _, flush}, Ctx) ->
  io:format("Flush: ~p~n", [Ctx]),
  {noreply, flush(Ctx)};
handle_info(Msg, Ctx) -> stepflow_channel:handle_info(Msg, Ctx).

terminate(_Reason, _Ctx) ->
  io:format("Terminate!!~n"),
  ok.

code_change(_OldVsn, Ctx, _Extra) ->
  io:format("code changed !"),
  {ok, Ctx}.

%% Private functions

-spec config(ctx()) -> {ok, ctx()}  | {error, term()}.
config(#{}=Config) ->
  FlushPeriod = maps:get(flush_period, Config, 3000),
  Capacity = maps:get(capacity, Config, 5),
  Table = maps:get(table, Config, stepflow_channel_mnesia_events),
  {ok, Config#{flush_period => FlushPeriod, capacity => Capacity,
               table => Table}}.

append(Events, #{table := Table}=Ctx) ->
  write(Table, Events),
  maybe_pop(Ctx).

create_schema() ->
  mnesia:create_schema([node()]),
  application:start(mnesia).

create_table(#{table := Table}) ->
  ok = case mnesia:create_table(Table, [
        {type, ordered_set},
        {attributes, record_info(fields, stepflow_channel_mnesia_events)},
        {record_name, stepflow_channel_mnesia_events},
        {disc_copies, [node()]}
      ]) of
    {atomic, ok} -> ok;
    {aborted,{already_exists, _}} -> ok;
    Error -> Error
  end,
  ok = mnesia:wait_for_tables([Table], 5000).

write(Table, Events) ->
  mnesia:activity(transaction, fun() ->
      % FIXME the capacity is wrong if put more than one event per row!
      mnesia:write(Table, #stepflow_channel_mnesia_events{
                      timestamp=os:timestamp(), events=Events
        }, write)
    end).

flush(#{chctx := #{skctx := _}, flush_period := FlushPeriod}=Ctx) ->
  io:format("Flush mnesia memory.. ~n"),
  erlang:start_timer(FlushPeriod, self(), flush),
  transactional_pop(Ctx).

-spec transactional_pop(ctx()) -> ctx().
transactional_pop(#{capacity := Capacity, table := Table}=Ctx) ->
  mnesia:activity(transaction, fun() ->
      Bulk = qlc:eval(catch_all(Table), [{max_list_size, Capacity}]),
      % TODO check if bulk is empty!
      Events = lists:flatten(
                 [R#stepflow_channel_mnesia_events.events || R <- Bulk]),
      Timestamps = [R#stepflow_channel_mnesia_events.timestamp || R <- Bulk],
      % process a bulk of events
      pop(Events, Ctx#{timestamps => Timestamps})
  end).

pop(Events, #{chctx := ChCtx}=Ctx) ->
  stepflow_channel:route(?MODULE, Ctx, Events, ChCtx).

maybe_pop(#{capacity := Capacity, table := Table}=Ctx) ->
  case mnesia:table_info(Table, size) >= Capacity of
    true -> transactional_pop(Ctx);
    false -> Ctx
  end.

catch_all(Table) ->
  qlc:q([R || R <- mnesia:table(Table)]).
