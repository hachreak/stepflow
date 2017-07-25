%%%-------------------------------------------------------------------
%% @doc stepflow event
%% @end
%%%-------------------------------------------------------------------

-module(stepflow_event).

-author('Leonardo Rossi <leonardo.rossi@studenti.unipr.it>').

-export([
  body/1,
  header/3,
  new/2
]).

-export_type([event/0]).

-type headers() :: map().
-type body()    :: any().
-type event()   :: #{binary() => headers(), binary() => body()}.


-spec new(headers(), body()) -> event().
new(Headers, Body) -> #{<<"headers">> => Headers, <<"body">> => Body}.

-spec body(event()) -> body().
body(#{<<"body">> := Body}) -> Body.

-spec header(binary() | string() | atom(), any(), event()) -> event().
header(Name, Value, #{<<"headers">> := Headers}=Event) ->
  Event#{<<"headers">> => Headers#{Name => Value}}.
