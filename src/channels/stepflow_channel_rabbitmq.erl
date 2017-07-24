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
  nack/1
]).

-type ctx()   :: map().
-type event() :: stepflow_event:event().
-type skctx() :: stepflow_channel:skctx().

%% Callbacks gen_server

-spec start_link(ctx()) -> {ok, pid()} | ignore | {error, term()}.
start_link(Config) ->
  gen_server:start_link(?MODULE, [Config], []).

-spec init(list(ctx())) -> {ok, ctx()}.
init([#{encoder := _}=Config]) ->
  {ok, Config#{status => offline}};
init([Config]) ->
  init([Config#{encoder => stepflow_encoder_json}]).

-spec handle_call(setup | {connect_sink, skctx()}, {pid(), term()}, ctx()) ->
    {reply, ok, ctx()}.
% @doc setup connection with the rabbitmq server @end
handle_call(setup, _From, Ctx) ->
  Ctx2 = handle_connect(Ctx),
  {reply, ok, Ctx2};
% @doc connect to the sink @end
handle_call({connect_sink, SinkCtx}, _From, Ctx) ->
  case handle_route(Ctx#{skctx => SinkCtx}) of
    {error, _}=Error -> {reply, Error, Ctx};
    {ok, Ctx2} -> {reply, ok, Ctx2}
  end;
handle_call(Input, _From, Ctx) ->
  {reply, Input, Ctx}.

-spec handle_cast({append, list(event())}, ctx()) -> {noreply, ctx()}.
% @doc append a new message inside the queue @end
handle_cast({append, Events}, #{exchange:=Exchange, routing_key:=RoutingKey,
                               channel:=Channel, encoder := Encoder}=Ctx) ->
  amqp_channel:cast(Channel, #'basic.publish'{
      exchange=Exchange, routing_key=RoutingKey
    }, #amqp_msg{payload=Encoder:encode(Events)}),
  {noreply, Ctx};
handle_cast(_, Ctx) ->
  {noreply, Ctx}.

handle_info(#'basic.consume_ok'{}, Ctx) ->
  %% This is the first message received
  {noreply, Ctx};
handle_info(#'basic.cancel_ok'{}, Ctx) ->
  %% This is received when the subscription is cancelled
  Ctx2 = disconnect(Ctx),
  {noreply, Ctx2};
% @doc new message to deliver to the sink. @end
handle_info({#'basic.deliver'{delivery_tag = Tag}, #amqp_msg{payload=Binary}},
            #{encoder := Encoder}=Ctx) ->
  %% A delivery
  case stepflow_channel:route(?MODULE, Encoder:decode(Binary),
                              Ctx#{tag => Tag}) of
    {ok, Ctx2} -> {noreply, Ctx2};
    {error, sink_fails} ->
      Ctx2 = disconnect(Ctx),
      {noreply, Ctx2}
  end;
handle_info(_Info, Ctx) ->
  {noreply, Ctx}.

terminate(_Reason, _Ctx) ->
  io:format("Terminate!!~n"),
  ok.

code_change(_OldVsn, Ctx, _Extra) ->
  io:format("code changed !"),
  {ok, Ctx}.

% -spec pop(skctx(), ctx()) -> {ok, skctx(), ctx()} | {error, term()}.
% pop(_SinkCtx, _Ctx) ->
%   % TODO implement!
%   {error, not_implemented}.
%   % get event
%   % case amqp_channel:call(Channel, #'basic.get'{
%   %     queue = Queue, no_ack = false}) of
%   %   #'basic.get_empty'{} -> {error, empty};
%   %   {#'basic.get_ok'{delivery_tag = Tag}, Events} ->
%   %     case process(Channel, Tag, Events, SinkCtx) of
%   %       {ok, SinkCtx2} -> {ok, SinkCtx2, Ctx};
%   %       {error, sink_fails}=Error -> Error
%   %     end
%   % end.

%% Callbacks channel

-spec config(ctx()) -> {ok, ctx()}  | {error, term()}.
config(Config) ->
  Host = maps:get(host, Config, "localhost"),
  Exchange = maps:get(exchange, Config, <<"stepflow_channel_rabbitmq">>),
  RoutingKey = maps:get(routing_key, Config, <<"stepflow_channel_rabbitmq">>),
  Port = maps:get(port, Config, 5672),
  {ok, Config#{exchange => Exchange, routing_key => RoutingKey, durable => true,
          host => Host, port => Port, queue => RoutingKey}}.

-spec ack(ctx()) -> {ok, ctx()}.
% @doc ack received, I can remove the events from memory. @end
ack(#{channel := Channel, tag := Tag}=Ctx) ->
  ok = amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),
  {ok, maps:remove(tag, Ctx)}.

-spec nack(ctx()) -> {ok, ctx()}.
% @doc nack received, leave the events inside the memory. @end
nack(Ctx)-> {ok, Ctx}.

%% Private functions

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

-spec handle_route(ctx()) -> {ok, ctx()} | {error, disconnected}.
handle_route(#{exchange := Exchange, channel := Channel, queue := Queue,
               routing_key := RoutingKey}=Ctx) ->
  % Create a routing rule from an exchange to a queue
  amqp_channel:call(Channel, #'queue.bind'{
    queue = Queue, exchange = Exchange, routing_key = RoutingKey}),
  % subscribe to a queue
  #'basic.consume_ok'{consumer_tag = _Tag} = amqp_channel:subscribe(
    Channel, #'basic.consume'{queue = Queue}, self()),
  {ok, Ctx};
handle_route(_) -> {error, disconnected}.

% Private functions

-spec disconnect(ctx()) -> ctx().
disconnect(
    #{status := online, connection := Connection, channel := Channel}=Ctx) ->
  %% Close the channel
  amqp_channel:disconnect(Channel),
  %% Close the connection
  amqp_connection:disconnect(Connection),
  Ctx#{status => offline};
disconnect(Ctx) -> Ctx.
