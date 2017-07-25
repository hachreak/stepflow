%% Tests

-module(stepflow_config_tests).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-include_lib("eunit/include/eunit.hrl").

load_test() ->
  stepflow_config:load("
    <<<
    SqueezeFun = fun(Events) ->
             BodyNew = lists:foldr(fun(Event, Acc) ->
                 Body = stepflow_event:body(Event),
                 << Body/binary, <<\" \">>/binary, Acc/binary >>
               end, <<\"\">>, Events),
             {ok, [stepflow_event:new(#{}, BodyNew)]}
           end.
    >>>

    interceptor Squeezer = stepflow_interceptor_transform#{
                                      eval => SqueezeFun
                                    }.
    source FromMsg = stepflow_source_message[Squeezer]#{}.
    channel Mnesia = stepflow_channel_mnesia#{
      flush_period => 10, capacity => 2, table => pippo
    }.
    sink Echo = stepflow_sink_echo[]#{}.

    flow Aggretator: FromMsg |> Mnesia |> Echo.
  "),

  stepflow_config:load("
    <<<
    FilterFun = fun(Events) ->
      lists:any(fun(E) -> E == <<\"filtered\">> end, Events)
    end.
    >>>

    interceptor Filter = stepflow_interceptor_filter#{filter => FilterFun}.
    interceptor Echo = stepflow_interceptor_echo#{}.
    source FromMsg = stepflow_source_message[]#{}.
    channel Memory = stepflow_channel_memory#{}.
    channel Rabbitmq = stepflow_channel_rabbitmq#{}.
    sink EchoMemory = stepflow_sink_echo[Echo]#{}.
    sink EchoRabbitmq = stepflow_sink_echo[Filter]#{}.

    flow Agent: FromMsg |> Memory   |> EchoMemory;
                        |> Rabbitmq |> EchoRabbitmq.
  "),

  stepflow_config:load("
    <<<
    FilterFun = fun(Events) ->
      lists:any(fun(Event) ->
          stepflow_event:body(Event) == <<\"found\">>
        end, Events)
    end.
    >>>

    interceptor Counter = stepflow_interceptor_counter#{
      header => mycounter, eval => FilterFun
    }.
    interceptor Show = stepflow_interceptor_echo#{}.
    source FromMsg = stepflow_source_message[]#{}.
    channel Rabbitmq = stepflow_channel_rabbitmq#{}.
    sink Echo = stepflow_sink_echo[Counter, Show]#{}.

    flow Agent: FromMsg |> Rabbitmq |> Echo.
  "),

  stepflow_config:load("
    interceptor Counter = stepflow_interceptor_counter#{}.
    source FromMsg = stepflow_source_message[Counter]#{}.
    channel Buffer = stepflow_channel_mnesia#{
        flush_period => 10, capacity => 7, table => mytable
    }.
    sink Echo = stepflow_sink_echo[]#{}.

    flow Squeeze: FromMsg |> Buffer |> Echo.
  "),

  stepflow_config:load("
    <<<
    SqueezeFun = fun(Events) ->
        BodyNew = lists:foldr(fun(Event, Acc) ->
            Body = stepflow_event:body(Event),
            << Body/binary, <<\" \">>/binary, Acc/binary >>
          end, <<\"\">>, Events),
        {ok, [stepflow_event:new(#{}, BodyNew)]}
      end.
    >>>

    interceptor Squeezer = stepflow_interceptor_transform#{
      eval => SqueezeFun
    }.
    source FromMsg = stepflow_source_message[Squeezer]#{}.
    channel Mnesia = stepflow_channel_mnesia#{
      flush_period => 10, capacity => 2, table => pippo
    }.
    sink Echo = stepflow_sink_echo[]#{}.

    flow Aggretator: FromMsg |> Mnesia |> Echo.
  "),

  stepflow_config:load("
    interceptor Counter = stepflow_interceptor_counter#{}.
    source FromMsg = stepflow_source_message[Counter]#{}.
    channel Memory = stepflow_channel_memory#{}.
    sink Elasticsearch = stepflow_sink_elasticsearch[]#{
      host => <<\"localhost\">>, port => 9200, index => <<\"myindex\">>
    }.

    flow Agent: FromMsg |> Memory |> Elasticsearch.
  "),

  ok.

multiple_definitions_test() ->
  ?_assertMatch(
    [
      {erlang,[
        {var,_,'Fuu'},
        {'=',_},
        {'fun',_},
        {'(',_},
        {')',_},
        {'->',_},
        {atom,_,io},
        {':',_},
        {atom,_,format},
        {'(',_},
        {string,_,"Hello worlds!~n"},
        {')',_},
        {'end',_},
        {dot,_}]},
      {interceptor, [
        {var,_,'Counter'},
        {'=',_},
        {'{',_},
        {atom,_,stepflow_interceptor_counter},
        {',',_},
        {'#',_},
        {'{',_},
        {atom,_,header},
        {'=>',_},
        {atom,_,mycounter},
        {'}',_},
        {'}',_},
        {dot,_}
      ]},
      {source, [
        {var,_,'FromMsg'},
        {'=',_},
        {'{',_},
        {atom,_,stepflow_source_message},
        {',',_},
        {'{',_},
        {'[',_},
        {var,_,'Counter'},
        {']',_},
        {',',_},
        {'#',_},
        {'{',_},
        {'}',_},
        {'}',_},
        {'}',_},
        {dot,_}
      ]},
      {flow, {test, {a, [{b, c}, {d, e}]}}}
    ],
    stepflow_config:load("
      <<<
        Fuu = fun() -> io:format(\"Hello worlds!~n\") end.
      >>>

      interceptor Counter = stepflow_interceptor_counter#{
          header => mycounter
      }.
      source FromMsg = stepflow_source_message[Counter]#{}.
      flow test: a |> b |> c;
                   |> d |> e.
    ")).

definition_interceptor_test() ->
  ?_assertMatch(
    [{interceptor, [
        {var,_,'Counter'},
        {'=',_},
        {'{',_},
        {atom,_,stepflow_interceptor_counter},
        {',',_},
        {'#',_},
        {'{',_},
        {atom,_,header},
        {'=>',_},
        {atom,_,mycounter},
        {'}',_},
        {'}',_},
        {dot,_}
      ]}],
    stepflow_config:load("
      interceptor Counter = stepflow_interceptor_counter#{
        header => mycounter
      }.
    ")).

definition_sink_test() ->
  ?_assertMatch(
    [{sink, [
      {var,_,'Echo'},
      {'=',_},
      {'{',_},
      {atom,_,stepflow_sink_echo},
      {',',_},
      {'{',_},
      {'[',_},
      {var,_,'Hello'},
      {',',_},
      {var,_,'World'},
      {']',_},
      {',',_},
      {'#',_},
      {'{',_},
      {atom,_,fuu},
      {'=>',_},
      {atom,_,bar},
      {'}',_},
      {'}',_},
      {'}',_},
      {dot,_}
    ]}],
    stepflow_config:load("
      sink Echo = stepflow_sink_echo[Hello, World]#{fuu => bar}.
    ")).

definition_channel_test() ->
  ?_assertMatch(
    [
      {channel, [
        {var,_,'Channel1'},
        {'=',_},
        {'{',_},
        {atom,_,stepflow_channel_rabbitmq},
        {',',_},
        {'#',_},
        {'{',_},
        {atom,_,fuu},
        {'=>',_},
        {atom,_,bar},
        {'}',_},
        {'}',_},
        {dot,_}
      ]}],
    stepflow_config:load("
      channel Channel1 = stepflow_channel_rabbitmq#{fuu => bar}.
    ")).

definition_source_test() ->
  ?_assertMatch(
    [
      {source,[
        {var,_,'Source1'},
        {'=',_},
        {'{',_},
        {atom,_,stepflow_source_message},
        {',',_},
        {'{',_},
        {'[',_},
        {var,_,'Counter1'},
        {',',_},
        {var,_,'Echo1'},
        {']',_},
        {',',_},
        {'#',_},
        {'{',_},
        {atom,_,fuu},
        {'=>',_},
        {atom,_,bar},
        {'}',_},
        {'}',_},
        {'}',_},
        {dot,_}
      ]}],
    stepflow_config:load("
      source Source1 = stepflow_source_message[Counter1, Echo1]#{
        fuu => bar
      }.
    ")).

definition_erlang_code_test() ->
  ?_assertMatch(
    [
      {erlang, [
        {var,_,'SqueezeFun'},
        {'=',_},
        {'fun',_},
        {'(',_},
        {var,_,'Events'},
        {')',_},
        {'->',_},
        {var,_,'BodyNew'},
        {'=',_},
        {atom,_,lists},
        {':',_},
        {atom,_,foldr},
        {'(',_},
        {'fun',_},
        {'(',_},
        {var,_,'Event'},
        {',',_},
        {var,_,'Acc'},
        {')',_},
        {'->',_},
        {var,_,'Body'},
        {'=',_},
        {atom,_,stepflow_event},
        {':',_},
        {atom,_,body},
        {'(',_},
        {var,_,'Event'},
        {')',_},
        {',',_},
        {'<<',_},
        {var,_,'Body'},
        {'/',_},
        {atom,_,binary},
        {',',_},
        {'<<',_},
        {string,_," "},
        {'>>',_},
        {'/',_},
        {atom,_,binary},
        {',',_},
        {var,_,'Acc'},
        {'/',_},
        {atom,_,binary},
        {'>>',_},
        {'end',_},
        {',',_},
        {'<<',_},
        {string,_,[]},
        {'>>',_},
        {',',_},
        {var,_,'Events'},
        {')',_},
        {',',_},
        {'{',_},
        {atom,_,ok},
        {',',_},
        {'[',_},
        {atom,_,stepflow_event},
        {':',_},
        {atom,_,new},
        {'(',_},
        {'#',_},
        {'{',_},
        {'}',_},
        {',',_},
        {var,_,'BodyNew'},
        {')',_},
        {']',_},
        {'}',_},
        {'end',_},
        {dot,_}
    ]}],
    stepflow_config:load("
      <<<
      SqueezeFun = fun(Events) ->
               BodyNew = lists:foldr(fun(Event, Acc) ->
                   Body = stepflow_event:body(Event),
                   << Body/binary, <<\" \">>/binary, Acc/binary >>
                 end, <<\"\">>, Events),
               {ok, [stepflow_event:new(#{}, BodyNew)]}
             end.
      >>>

")).
