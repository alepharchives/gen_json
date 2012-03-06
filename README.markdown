## gen_json (v0.9) ##

generic json handling utilities for [jsx][jsx]

copyright 2012 alisdair sullivan

gen_json is released under the terms of the [MIT][MIT] license

to build gen_json, use `make`. to run the test suite, use `make test`.


## api ##

[jsx][jsx] is implemented as a set of scanners that produce tokens consumed be functions that transform them into various representations. gen_json is an interface to allow arbitrary representations/actions to be taken upon scanning a json text or erlang term representation of a json text


**the gen_json parser**

`gen_json:parser(Mod)` -> `Result`

`gen_json:parser(Mod, Args)` -> `Result`

`gen_json:parser(Mod, Args, Opts)` -> `Result`

types:

* `Mod` = module()
* `Args` = any()
* `Opts` = see note below

`Mod` is the callback module implementing the `gen_json` behaviour

`Args` will be passed to `Mod:init/1` as is

`Result` will be the return from `Mod:handle_event(end_json, State)`

in general, `Opts` will be passed as is to the scanner. the scanner will be automatically selected based on input type. to specify a specific scanner, you may use the options `{parser, Parser}` where `Parser` can currently be one of `auto`, `encoder` or `decoder`. `auto` is the default behaviour, `encoder` will only accept erlang terms (as in the mapping detailed above) and `decoder` will only accept json texts. note that to parse naked erlang terms as json, you MUST specify `{parser, encoder}`. more scanners may be added in the future


modules that implement the `gen_json` behaviour must implement the following two functions


**init**

produces the initial state for a gen_json handler

`init(Args)` -> `InitialState`

types:

* `Args` = `any()`
* `InitialState` = `any()`

`Args` is the argument passed to `gen_json/2` above as `Args`. when `gen_json/1` is called, `Args` will equal `[]` 


**handle_event**

`handle_event/2` will be called for each token along with the current state of the handler and should produce a new state

`handle_event(Event, State)` -> `NewState`

types:

* `Event` =
    - `start_object`
    - `end_object`
    - `start_array`
    - `end_array`
    - `end_json`
    - `{key, binary()}`
    - `{string, binary()}`
    - `{integer, integer()}`
    - `{float, float()}`
    - `{literal, true}`
    - `{literal, false}`
    - `{literal, null}` 
* `State` = `any()`

`Event` types are the same as [jsx][jsx], see that project for details

any cleanup in your handler should be done upon receiving `end_json` as it will always be the last token received


[jsx]: http://github.com/talentdeficit/jsx
[MIT]: http://www.opensource.org/licenses/mit-license.html