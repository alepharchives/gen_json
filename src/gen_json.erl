%% The MIT License

%% Copyright (c) 2012 Alisdair Sullivan <alisdairsullivan@yahoo.ca>

%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:

%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.

%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.


-module(gen_json).

-export([behaviour_info/1]).
-export([parser/1, parser/2, parser/3]).
-export([handle_event/2, init/1]).


-type events() :: [event()].
-type event() :: start_object
    | end_object
    | start_array
    | end_array
    | end_json
    | {key, list()}
    | {string, list()}
    | {integer, integer()}
    | {float, float()}
    | {literal, true}
    | {literal, false}
    | {literal, null}.

-type opts() :: [opt()].
-type opt() :: loose_unicode
        | escape_forward_slashes
        | explicit_end
        | {parser, auto} | {parser, encoder} | {parser, decoder} | {parser, function()}.

-export_type([events/0, event/0, opts/0, opt/0]).


behaviour_info(callbacks) -> [{init, 0}, {handle_event, 2}];
behaviour_info(_) -> undefined.


parser(F) -> parser(F, []).

parser(F, Opts) when is_function(F, 1) -> parser(?MODULE, {F, undefined}, Opts);
parser({F, State}, Opts) when is_function(F, 2) -> parser(?MODULE, {F, State}, Opts);
parser(Mod, Args) -> parser(Mod, Args, []).

parser(Mod, Args, Opts) when is_atom(Mod), is_list(Opts) ->
    case proplists:get_value(parser, Opts, auto) of
        auto ->
            fun(Input) when is_list(Input) -> (jsx:encoder(Mod, Args, Opts))(Input)
                ; (Input) when is_binary(Input) -> (jsx:decoder(Mod, Args, Opts))(Input)
            end
        ; encoder ->
            fun(Input) -> (jsx:encoder(Mod, Args, Opts))(Input) end
        ; decoder ->
            fun(Input) -> (jsx:decoder(Mod, Args, Opts))(Input) end
    end.


handle_event(end_json, {F, undefined}) -> F(end_json), ok;
handle_event(end_json, {F, State}) -> F(end_json, State);
handle_event(Event, {F, undefined}) -> F(Event), {F, undefined};
handle_event(Event, {F, State}) -> {F, F(Event, State)}.

init(State) -> State.


-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

fake_xxcoder(Expected) ->
    F = fun(Mod, State, _) ->
        fun(_) ->
            lists:foldl(
                fun(Event, Acc) -> Mod:handle_event(Event, Acc) end,
                State,
                Expected
            )
        end
    end,
    meck:expect(jsx, decoder, F),
    meck:expect(jsx, encoder, F).


anon_one() -> fun(Event) -> self() ! Event end.

anon_two() ->
    fun(end_json, Acc) -> lists:reverse([end_json] ++ Acc);
        (Event, Acc) -> [Event] ++ Acc
    end.

receive_all() -> receive_all([]).

receive_all(Acc) ->
    receive
        X -> receive_all([X] ++ Acc)
    after
        60 -> lists:reverse(Acc)
    end.


anon_test_() ->
    Events = [
        start_array,
        {integer, 1},
        {literal, true},
        end_array,
        end_json
    ],
    {foreach,
        fun() ->
            meck:new(jsx),
            fake_xxcoder(Events) 
        end,
        fun(_) ->
            ?assert(meck:validate(jsx)),
            meck:unload(jsx)
        end,
        [
            {"arity 1 anon fun", ?_assertEqual(
                begin
                    (parser(anon_one()))(<<"[1, true]">>),
                    Events
                end,
                receive_all()
            )},
            {"arity 2 anon fun", ?_assertEqual(
                (parser({anon_two(), []}))(<<"[1, true]">>),
                Events
            )}
        ]
    }.

external_test_() ->
    Events = [
        start_array,
        {integer, 1},
        {literal, true},
        end_array,
        end_json
    ],
    {foreach,
        fun() ->
            meck:new(jsx),
            fake_xxcoder(Events),
            meck:new(handler),
            meck:expect(handler, handle_event, fun(end_json, Acc) ->
                        lists:reverse([end_json] ++ Acc);
                    (Event, Acc) -> [Event] ++ Acc
                end
            ),
            meck:expect(handler, init, fun(State) -> State end)
        end,
        fun(_) ->
            ?assert(meck:validate(jsx)),
            ?assert(meck:validate(handler)),
            meck:unload(jsx),
            meck:unload(handler)
        end,
        [
            {"external handler", ?_assertEqual(
                (parser(handler, []))(<<"[1, true]">>),
                Events
            )}
        ]
    }.

-endif.