%%%-------------------------------------------------------------------
%% @doc stepflow channel rabbitmq
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_channel_rabbitmq).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-behaviour(stepflow_channel).

-include_lib("amqp_client/include/amqp_client.hrl").

-export([
  handle_append/2,
  handle_init/2,
  handle_pop/2,
  loop/1
]).

-type ctx()   :: list().
-type event() :: stepflow_channel:event().
-type skctx() :: stepflow_channel:skctx().

-spec handle_init(ctx(), skctx()) -> {ok, ctx()} | {error, term()}.
handle_init(Config, SinkCtx) ->
  Ctx = connect(config(Config, SinkCtx)),
  {ok, Ctx}.

-spec handle_append(event(), ctx()) -> {ok, ctx()} | {error, term()}.
handle_append(Event, #{channel := Channel, exchange := Exchange,
                       routing_key := RoutingKey}=Ctx) ->
  amqp_channel:cast(Channel, #'basic.publish'{
      exchange=Exchange, routing_key=RoutingKey
    }, #amqp_msg{payload=Event}),
  {ok, Ctx}.

-spec handle_pop(skctx(), ctx()) ->
    {ok, skctx(), ctx()} | {error, term()}.
handle_pop(_SinkCtx, _Ctx) ->
  % TODO implement!
  {error, not_implemented}.
  % get event
  % case amqp_channel:call(Channel, #'basic.get'{
  %     queue = Queue, no_ack = false}) of
  %   #'basic.get_empty'{} -> {error, empty};
  %   {#'basic.get_ok'{delivery_tag = Tag}, Event} ->
  %     case process(Channel, Tag, Event, SinkCtx) of
  %       {ok, SinkCtx2} -> {ok, SinkCtx2, Ctx};
  %       {error, sink_fails}=Error -> Error
  %     end
  % end.

%% Private functions

config(Config, SinkCtx) ->
  Host = maps:get(host, Config, "localhost"),
  Exchange = maps:get(exchange, Config, <<"stepflow_channel_rabbitmq">>),
  RoutingKey = maps:get(routing_key, Config, <<"stepflow_channel_rabbitmq">>),
  Port = maps:get(port, Config, 5672),
  Config#{exchange => Exchange, routing_key => RoutingKey, durable => true,
          host => Host, port => Port, skctx => SinkCtx, queue => RoutingKey}.

connect(#{is_connected := true}=Ctx) -> Ctx;
connect(#{host := Host, exchange := Exchange, durable := Durable,
          routing_key := RoutingKey, port := Port, skctx := SinkCtx,
          queue := Queue}=Config) ->
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
  % Create a routing rule from an exchange to a queue
  amqp_channel:call(Channel, #'queue.bind'{
    queue = Queue, exchange = Exchange, routing_key = RoutingKey}),

  receiver(Connection, Channel, SinkCtx, Queue),

  Config#{channel => Channel, connection => Connection, queue => Queue,
          is_connected => true}.

receiver(Connection, Channel, SinkCtx, Queue) ->
  % run a process to receive messages
  Pid = spawn_link(stepflow_channel_rabbitmq, loop,
             [{Connection, Channel, SinkCtx}]),
  % subscribe to a queue
  #'basic.consume_ok'{consumer_tag = _Tag} = amqp_channel:subscribe(
    Channel, #'basic.consume'{queue = Queue}, Pid).

loop({Connection, Channel, SinkCtx}=Config) ->
  receive
    %% This is the first message received
    #'basic.consume_ok'{} -> loop(Config);
    %% This is received when the subscription is cancelled
    #'basic.cancel_ok'{} -> close(Connection, Channel);
    %% A delivery
    {#'basic.deliver'{delivery_tag = Tag}, #amqp_msg{payload=Event}} ->
      case process(Channel, Tag, Event, SinkCtx) of
        {ok, SinkCtx2} -> loop({Connection, Channel, SinkCtx2});
        {error, sink_fails}=Error ->
          close(Connection, Channel),
          Error
      end
  end.

process(Channel, Tag, Event, SinkCtx) ->
  case stepflow_sink:process(Event, SinkCtx) of
    {ok, SinkCtx2} ->
      % ack received, I can remove the event from memory
      ok = amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),
      {ok, SinkCtx2};
      % {error, sink_fails};
    {error, _} ->
      % something goes wrong! Leave memory as it is.
      ok = amqp_channel:cast(Channel, #'basic.nack'{delivery_tag = Tag}),
      {error, sink_fails}
  end.

close(Connection, Channel) ->
  %% Close the channel
  amqp_channel:close(Channel),
  %% Close the connection
  amqp_connection:close(Connection).
