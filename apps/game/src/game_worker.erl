-module(game_worker).
-behaviour(gen_server).

-include_lib ("datatypes/include/game.hrl").
-include_lib ("datatypes/include/bucket.hrl").
-include_lib ("eunit/include/eunit.hrl").

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------
-export([start_link/0, ping/0]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2,
         code_change/3]).

%% server state
-record(state, {}).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

start_link() ->
    gen_server:start_link(?MODULE, no_arg, []).

ping() ->
    gen_server:call(service_worker:select_pid(?MODULE), ping).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

-spec init (no_arg) -> no_return ().
init(no_arg) ->
    service_worker:join_group(?MODULE),
    {ok, #state{}}.

handle_call(ping, _From, State) ->
    {reply, {pong, self()}, State};


handle_call({put_game_order, Key, GameMove}, _From, State) ->
    Reply = put_game_order(Key, GameMove),
    {reply, Reply, State};
handle_call({update_game_order, Key, GameMove}, _From, State) ->
    Reply = update_game_order(Key, GameMove),
    {reply, Reply, State};
handle_call({get_game_order, Key}, _From, State) ->
    Reply = get_game_order(Key),
    {reply, Reply, State};
handle_call({new_game, Game=#game{id = ID}}, _From, State) ->
    Reply = new_game(ID, Game),
    {ok, NewID} = Reply,
    {ok, NewGame} = get_game(NewID),
    game_timer_sup:create_timer(NewGame),
    game_timer:event(NewID, start),
    {reply, Reply, State};
handle_call({reconfig_game, Game=#game{id = ID}}, _From, State) ->
    Reply = update_game(ID, Game),
    game_timer:event(ID, {reconfig, Game}),
    {reply, Reply, State};
handle_call({get_game, ID}, _From, State) ->
    Reply = get_game(ID),
    {reply, Reply, State};
handle_call({join_game, GameID, UserID, Country}, _From, State) ->
    BinID = db:int_to_bin(GameID),
    DBReply = db:get (?B_GAME_PLAYER, BinID),
    Reply = case DBReply of
        {ok, DBObj} ->
            join_game(BinID, GameID, DBObj, UserID, Country);
        Other ->
            Other
    end,
    {reply, Reply, State};
handle_call({get_game_player, GameID}, _From, State) ->
    Reply = get_game_player(GameID),
    {reply, Reply, State};

handle_call({get_game_state, GameID, UserID}, _From, State) ->
    Reply =get_game_state(GameID, UserID),
    {reply, Reply, State};

handle_call({delete_game, Key}, _From, State) ->
    BinKey = list_to_binary(integer_to_list(Key)),
    Reply = db:delete(?B_GAME, BinKey),
    {reply, Reply, State};
handle_call(_Request, _From, State) ->
    io:format ("received unhandled call: ~p~n",[{_Request, _From, State}]),
    {noreply, ok, State}.

handle_cast({phase_change, Game, NewPhase}, State) ->
    phase_change(Game, NewPhase),
    {noreply, State};
handle_cast(_Msg, State) ->
    io:format ("received unhandled cast: ~p~n",[{_Msg, State}]),
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    io:format ("[~p] terminated ~p: reason: ~p, state: ~p ~n",
               [?MODULE, self(), _Reason, _State]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------
put_game_order(ID, GameMoveRecList) ->
    BinID = list_to_binary(ID),
    DBGameMoveObj = db_obj:create (?B_GAME_ORDER, BinID, GameMoveRecList),
    db:put (DBGameMoveObj),
    {ok, ID}.

update_game_order(ID, NewOrder) ->
    case db:get(?B_GAME_ORDER, list_to_binary(ID)) of
        {ok, Obj} ->
            NewObj = db_obj:set_value(Obj, NewOrder),
            db:put(NewObj),
            {ok, NewOrder};
        Error ->
            {error, Error}
    end.

new_game(undefined, #game{} = Game) ->
    ID = db:get_unique_id(),
    new_game(ID, Game#game{id = ID});
new_game(ID, #game{} = Game) ->
    BinID = db:int_to_bin(ID),
    DBGameObj=db_obj:create (?B_GAME, BinID, Game),
    DBGamePlayerObj=db_obj:create (?B_GAME_PLAYER, BinID, #game_player{id=ID}),
    db:put (DBGameObj),
    db:put (DBGamePlayerObj),
    {ok, ID}.

update_game(ID, #game{} = Game) ->
    BinID = db:int_to_bin(ID),
    DBGameObj=db_obj:create (?B_GAME, BinID, Game),
    db:put (DBGameObj),
    {ok, ID}.


join_game(BinID, GameID, GameDBObj, UserID, Country) ->
    GP = db_obj:get_value (GameDBObj),
    case lists:keyfind(Country, #game_user.country,GP#game_player.players) of
        false -> % if the country is available
            NewPlayer= #game_user{id=UserID, country=Country},
            UpdatedGP = GP#game_player{players=
                                     [NewPlayer|GP#game_player.players]},
            NewDBObj=db_obj:create (?B_GAME_PLAYER, BinID, UpdatedGP),
            NewDBLinkObj = db_obj:add_link(NewDBObj,
                                           {{?B_USER, db:int_to_bin(UserID)},
                                            ?GAME_PLAYER_LINK_USER}),

            db:put (NewDBLinkObj),
            {ok, GameID};
        _ ->
            {error, country_not_available}
       end.




get_game(ID)->
    BinID = db:int_to_bin(ID),
    DBReply = db:get(?B_GAME, BinID),
    case DBReply of
        {ok, DBObj} ->
            {ok, db_obj:get_value (DBObj)};
        Other ->
            Other
    end.

get_game_player(GameID)->
    BinID = db:int_to_bin(GameID),
    DBReply = db:get (?B_GAME_PLAYER, BinID),
    case DBReply of
        {ok, DBObj} ->
            {ok, db_obj:get_value (DBObj)};
        Other ->
            Other
    end.

get_game_state(GameID, UserID) ->
    case get_game_player(GameID) of
        {ok, GPRec = #game_player{}} ->
            case lists:keyfind(UserID, #game_user.id,
                               GPRec#game_player.players) of
                false ->
                    {error, user_not_playing_this_game};
                GU = #game_user{} ->
                    get_game_map(GameID, #game_overview
                                               {country = GU#game_user.country})
            end;
        Other ->
            Other

    end.

get_game_map(GameID, #game_overview{} = GameOverview) ->
    {ok, Game=#game{status= Status}} = get_game(GameID),
    case Status of
        waiting ->
            Map = map_data:create (standard_game),
            GameOV = GameOverview#game_overview{game_rec= Game,
                                                map = digraph_io:to_erlang_term(Map)},
            {ok, GameOV};
        _ -> %TODO provide state for other type of games which are not waiting
            {error, game_not_waiting}
    end.


phase_change(Game, NewPhase) ->
    case NewPhase of
        order_phase ->
            ok;
        retreat_phase ->
            %% after evaluating the orders, and retreat phase is not needed
            %% send back an event game_timer(Gameid, Event)
            %% to skip retreat phase: game_timer:event(Game#game.id, skip);
            ok;
        build_phase ->
            %% check if build phase is needed, if not, send an event
            %% to the game_timer
            %% to skip phase if not needed: game_timer:event(Game#game.id, skip)
            ok;
        started ->
            %% update the game in the db (it is now ongoing)
            %% this is only the first time, continue as the order_phase case
            update_game(Game#game.id, Game),
            %% do some other stuff that's needed...
            ok
    end.

get_game_order(ID)->
    BinID = list_to_binary(ID),
    DBReply = db:get(?B_GAME_ORDER, BinID),
    case DBReply of
        {ok, DBObj} ->
            {ok, db_obj:get_value (DBObj)};
        Other ->
            Other
    end.
