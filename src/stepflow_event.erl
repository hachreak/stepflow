%%%-------------------------------------------------------------------
%% @doc stepflow event
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_event).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  body/1,
  body/2,
  header/2,
  header/3,
  headers/1,
  new/2
]).

-export_type([event/0]).

-type key()     :: binary() | string() | atom().
-type headers() :: map().
-type body()    :: any().
-type event()   :: #{binary() => headers(), binary() => body()}.


-spec new(headers(), body()) -> event().
new(Headers, Body) -> #{<<"headers">> => Headers, <<"body">> => Body}.

-spec body(event()) -> body().
body(#{<<"body">> := Body}) -> Body.

-spec body(body(), event()) -> event().
body(Body, Event) -> Event#{<<"body">> := Body}.

-spec header(key(), any(), event()) -> event().
header(Name, Value, #{<<"headers">> := Headers}=Event) ->
  Event#{<<"headers">> => Headers#{Name => Value}}.

-spec header(key(), event()) -> any().
header(Name, #{<<"headers">> := Headers}) -> maps:get(Name, Headers).

-spec headers(event()) -> headers().
headers(#{<<"headers">> := Headers}) -> Headers.
