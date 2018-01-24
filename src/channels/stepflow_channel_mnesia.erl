%%%-------------------------------------------------------------------
%% @doc stepflow channel mnesia
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_channel_mnesia).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_channel).

-include_lib("stdlib/include/qlc.hrl").

-export([
  ack/1,
  append/2,
  connect/1,
  disconnect/1,
  handle_call/3,
  handle_cast/2,
  handle_info/2,
  init/1,
  nack/1,
  set_sink/2
]).

-type ctx() :: map().

-record(stepflow_channel_mnesia_events, {timestamp, events}).

%% Callbacks channel

-spec ack(ctx()) -> ctx().
ack(#{timestamps := Timestamps, table := Table}=Ctx) ->
  % TODO improve deleting all in one time!
  mnesia:activity(transaction, fun() ->
      [mnesia:delete({Table, Timestamp}) || Timestamp <- Timestamps]
    end),
  maps:remove(timestamps, Ctx).

-spec nack(ctx()) -> ctx().
nack(Ctx)-> maps:remove(timestamps, Ctx).

set_sink(_SkCtx, Ctx) -> Ctx.

connect(Ctx) ->
  create_schema(),
  create_table(Ctx),
  flush(Ctx).

disconnect(Ctx) -> Ctx.

init(Config) ->
  {ok, Ctx} = config(Config),
  Ctx.

append(Events, #{table := Table}=Ctx) ->
  write(Table, Events),
  maybe_run(fun() -> stepflow_channel:pop(self()) end, Ctx),
  Ctx.

handle_call(Msg, _From, Ctx) ->
  error_logger:warning_msg("[Channel] not implemented ~p~n", [Msg]),
  {reply, not_implemented, Ctx}.

handle_cast(pop, Ctx) ->
  transactional_pop(Ctx);

handle_cast(Msg, Ctx) ->
  error_logger:warning_msg("[Channel] not implemented ~p~n", [Msg]),
  {noreply, Ctx}.

handle_info({timeout, _, flush}, Ctx) ->
  {noreply, flush(Ctx)};

handle_info(Msg, Ctx) ->
  error_logger:warning_msg("[Channel] not implemented ~p~n", [Msg]),
  {noreply, Ctx}.

%% Private functions

-spec config(ctx()) -> {ok, ctx()}  | {error, term()}.
config(#{}=Config) ->
  FlushPeriod = maps:get(flush_period, Config, 3000),
  Capacity = maps:get(capacity, Config, 3),
  Table = maps:get(table, Config, stepflow_channel_mnesia_events),
  {ok, Config#{flush_period => FlushPeriod, capacity => Capacity,
               table => Table}}.

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

flush(#{flush_period := FlushPeriod}=Ctx) ->
  io:format("Flush mnesia memory.. ~n"),
  erlang:start_timer(FlushPeriod, self(), flush),
  stepflow_channel:pop(self()),
  Ctx.
  % transactional_pop(Ctx).

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

pop(Events, Ctx) ->
  {route, Events, Ctx}.

maybe_run(Fun, #{capacity := Capacity, table := Table}) ->
  case mnesia:table_info(Table, size) >= Capacity of
    true -> Fun();
    false -> ok
  end.

catch_all(Table) ->
  qlc:q([R || R <- mnesia:table(Table)]).
