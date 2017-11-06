%% Tests

-module(stepflow_event_tests).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-include_lib("eunit/include/eunit.hrl").

new_test() ->
  Headers = #{<<"a">> => <<"b">>, <<"c">> => <<"d">>},
  Event = stepflow_event:new(Headers, <<"hello">>),
  % check header
  ?assertEqual(<<"b">>, stepflow_event:header(<<"a">>, Event)),
  % check change header
  ?assertEqual(<<"e">>, stepflow_event:header(
          <<"a">>, stepflow_event:header(<<"a">>, <<"e">>, Event))),
  % check all headers
  ?assertEqual(Headers, stepflow_event:headers(Event)),
  % check body
  ?assertEqual(<<"hello">>, stepflow_event:body(Event)),
  % check update body
  Event2 = stepflow_event:body(<<"world">>, Event),
  ?assertEqual(<<"world">>, stepflow_event:body(Event2)),

  ok.
