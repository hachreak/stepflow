%%%-------------------------------------------------------------------
%% @doc stepflow channel rabbitmq
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_channel_rabbitmq).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_channel).
-behaviour(gen_server).

-include_lib("amqp_client/include/amqp_client.hrl").

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
  config/1,
  update_chctx/2,
  nack/1
]).

-type ctx()   :: map().
-type event() :: stepflow_event:event().

%% Callbacks gen_server

-spec start_link(ctx()) -> {ok, pid()} | ignore | {error, term()}.
start_link(Config) ->
  gen_server:start_link(?MODULE, [Config], []).

-spec init(list(ctx())) -> {ok, ctx()}.
init([{SkCtx, Config}]) ->
  Config2 = config(Config),
  Config3 = case stepflow_channel:init(SkCtx) of
    {ok, ChCtx} -> connect_to_sink(update_chctx(disconnect(Config2), ChCtx));
    no_sink -> Config2
  end,
  {ok, Config3}.

-spec handle_call(any(), {pid(), term()}, ctx()) -> {reply, ok, ctx()}.
handle_call(debug, _From, Ctx) ->
  {reply, Ctx, Ctx};
handle_call(Input, _From, Ctx) ->
  {reply, Input, Ctx}.

-spec handle_cast({append, list(event())}, ctx()) -> {noreply, ctx()}.
% @doc append a new message inside the queue @end
handle_cast({append, Events}, Ctx) ->
  {noreply, append(Events, Ctx)};
handle_cast(Msg, Ctx) -> stepflow_channel:handle_cast(Msg, Ctx).

handle_info(#'basic.consume_ok'{}, Ctx) ->
  %% This is the first message received
  {noreply, Ctx};
handle_info(#'basic.cancel_ok'{}, Ctx) ->
  %% This is received when the subscription is cancelled
  Ctx2 = disconnect(Ctx),
  {noreply, Ctx2};
% @doc new message to deliver to the sink. @end
handle_info({#'basic.deliver'{}, _}=Msg, Ctx) -> {noreply, pop(Msg, Ctx)};
handle_info(Msg, Ctx) -> stepflow_channel:handle_info(Msg, Ctx).

terminate(_Reason, _Ctx) ->
  io:format("Terminate!!~n"),
  ok.

code_change(_OldVsn, Ctx, _Extra) ->
  io:format("code changed !"),
  {ok, Ctx}.

%% Callbacks channel

update_chctx(Ctx, ChCtx) -> Ctx#{chctx => ChCtx}.

-spec ack(ctx()) -> ctx().
ack(#{channel := Channel, tag := Tag}=Ctx) ->
  ok = amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),
  maps:remove(tag, Ctx).

-spec nack(ctx()) -> ctx().
nack(Ctx)->
  % TODO add a strategy to reconnect!
  disconnect(Ctx),
  Ctx.

%% Private functions

connect_to_sink(#{chctx := #{skctx := _}}=Ctx) ->
  Ctx2 = handle_connect(Ctx),
  % connect to the sink
  case queue_binding(Ctx2) of
    {error, _}=_Error ->
      error_logger:warning_msg("[Channel] error connecting to the sink~n"),
      Ctx2;
    {ok, Ctx3} -> Ctx3
  end;
connect_to_sink(Ctx) ->
  error_logger:warning_msg("[Channel] no sink configured~n"),
  Ctx.

-spec config(ctx()) -> {ok, ctx()}  | {error, term()}.
config(Config) ->
  Host = maps:get(host, Config, "localhost"),
  Exchange = maps:get(exchange, Config, <<"stepflow_channel_rabbitmq">>),
  RoutingKey = maps:get(routing_key, Config, <<"stepflow_channel_rabbitmq">>),
  Port = maps:get(port, Config, 5672),
  Encoder = maps:get(encoder, Config, stepflow_encoder_json),
  Config#{exchange => Exchange, routing_key => RoutingKey,
               durable => true, encoder => Encoder,
               host => Host, port => Port, queue => RoutingKey}.

append(Events, #{exchange:=Exchange, routing_key:=RoutingKey,
                 channel:=Channel, encoder := Encoder}=Ctx) ->
  amqp_channel:cast(Channel, #'basic.publish'{
      exchange=Exchange, routing_key=RoutingKey
    }, #amqp_msg{payload=Encoder:encode(Events)}),
  Ctx.

pop({#'basic.deliver'{delivery_tag = Tag}, #amqp_msg{payload=Binary}},
        #{encoder := Encoder, chctx := ChCtx}=Ctx) ->
  stepflow_channel:route(
    ?MODULE, Ctx#{tag => Tag}, Encoder:decode(Binary), ChCtx).

-spec handle_connect(ctx()) -> ctx().
handle_connect(#{status := online}=Ctx) -> Ctx;
handle_connect(#{host := Host, exchange := Exchange, durable := Durable,
          port := Port, queue := Queue}=Config) ->
  {ok, Connection} =
        amqp_connection:start(#amqp_params_network{host = Host, port = Port}),
  % Open a channel
  {ok, Channel} = amqp_connection:open_channel(Connection),
  % Declare a exchange
  #'exchange.declare_ok'{} = amqp_channel:call(
    Channel, #'exchange.declare'{
      exchange = Exchange, type = <<"direct">>, durable = Durable}),
  % queue declare
  #'queue.declare_ok'{} = amqp_channel:call(
                             Channel, #'queue.declare'{queue=Queue}),
  Config#{channel => Channel, connection => Connection, queue => Queue,
          status => online}.

-spec queue_binding(ctx()) -> {ok, ctx()} | {error, disconnected}.
queue_binding(#{exchange := Exchange, channel := Channel, queue := Queue,
               routing_key := RoutingKey}=Ctx) ->
  % Create a routing rule from an exchange to a queue
  amqp_channel:call(Channel, #'queue.bind'{
    queue = Queue, exchange = Exchange, routing_key = RoutingKey}),
  % subscribe to a queue
  #'basic.consume_ok'{consumer_tag = _Tag} = amqp_channel:subscribe(
    Channel, #'basic.consume'{queue = Queue}, self()),
  {ok, Ctx};
queue_binding(_) -> {error, disconnected}.

% Private functions

-spec disconnect(ctx()) -> ctx().
disconnect(
    #{status := online, connection := Connection, channel := Channel}=Ctx) ->
  %% Close the channel
  amqp_channel:disconnect(Channel),
  %% Close the connection
  amqp_connection:disconnect(Connection),
  Ctx#{status => offline};
disconnect(Ctx) -> Ctx#{status => offline}.
