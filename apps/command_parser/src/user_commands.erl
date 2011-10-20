%%%-------------------------------------------------------------------
%%% @copyright
%%% COPYRIGHT
%%% @end
%%%-------------------------------------------------------------------
%%% @doc user_command
%%%
%%% A module for recognizing user command in email body
%%%
%%% @end
%%%
%%%-------------------------------------------------------------------
-module(user_commands).

%Export for API
-export([parse_register/1, parse_login/1]).

%Export for eunit test
-export([reg_info_refine/1, new_user_record/1, get_reg_info/1]).

-include_lib("datatypes/include/user.hrl").% -record(user,{})
-include("include/records.hrl").% -record(reg_info,{})


%%------------------------------------------------------------------------------
%% @doc parse_login/1
%%
%% Parses a login string into {Nick, Password}
%% @end
%%------------------------------------------------------------------------------
parse_login(_BinStr) ->
    {error, not_yet_implemented}.

%%------------------------------------------------------------------------------
%% @doc parse_register/1
%%
%% Parses a register string into a user record.
%% @end
%%------------------------------------------------------------------------------
parse_register(BinStr) ->
    case get_reg_info(BinStr) of
        {ok, RegInfo} ->
            {ok, new_user_record(RegInfo)};
        Error ->
            Error
    end.
get_reg_info(BinStr) ->
    HeadPos = binary:match(BinStr, <<"REGISTER\r\n">>),
    case HeadPos of
        {_,_} ->
            HeadCut = bin_utils:tailstr(BinStr, HeadPos),
            TailPos = binary:match(HeadCut, <<"\r\nEND">>),
            case TailPos of
                {_,_} ->
                    TailCut = bin_utils:headstr(HeadCut, TailPos),
                    RawInfoList = binary:split(TailCut, <<"\r\n">>, [global, trim]),
                    reg_info_refine(RawInfoList);
                _ -> {error, no_reg_end}
            end;
        _ ->
            {error, no_reg_start}
    end.


%%------------------------------------------------------------------------------
%% @doc reg_info_refine/1
%%
%% Convert reg_info record to user record.
%% @end
%%------------------------------------------------------------------------------
reg_info_refine([], OutputRecord) ->
    {ok, OutputRecord};
reg_info_refine([H|Rest], OutputRecord) ->
    case binary:split(H, <<":">>) of
        [Field, Value]
          when H =/= <<>> -> % if current line has ":", proceed further syntax analysis
            Field1 = bin_utils:strip(Field),
            Value1 = bin_utils:strip(Value),

            case Field1 of % check of valid field type
                <<"NICKNAME">> ->
                    reg_info_refine(Rest, #reg_info{
                        nick = Value1,
                        password = OutputRecord#reg_info.password,
                        email = OutputRecord#reg_info.email,
                        name = OutputRecord#reg_info.name
                    });
                <<"PASSWORD">> ->
                    reg_info_refine(Rest, #reg_info{
                        nick = OutputRecord#reg_info.nick,
                        password = Value1,
                        email = OutputRecord#reg_info.email,
                        name = OutputRecord#reg_info.name
                    });
                <<"EMAIL">> ->
                    case binary:match(Value1, <<"@">>) of
                        {_,_} ->
                            reg_info_refine(Rest, #reg_info{
                                nick = OutputRecord#reg_info.nick,
                                password = OutputRecord#reg_info.password,
                                email = Value1,
                                name = OutputRecord#reg_info.name
                            });
                        _ ->
                            {error, invalid_email_address}
                    end;
                <<"FULLNAME">> ->
                    reg_info_refine(Rest, #reg_info{
                        nick = OutputRecord#reg_info.nick,
                        password = OutputRecord#reg_info.password,
                        email = OutputRecord#reg_info.email,
                        name = Value1
                    });
                _ ->
                    reg_info_refine(Rest, OutputRecord)
            end;
        _ -> % if current line doen't have ":", skip this line
            reg_info_refine(Rest, OutputRecord)
    end.
reg_info_refine(InfoList) ->
    reg_info_refine(InfoList, #reg_info{}).


%%--------------------------------------------------------------------------
%% @doc new_user_record/1
%%
%% Convert reg_info record to user record.
%% @end
%%--------------------------------------------------------------------------
new_user_record(RegInfo) ->
    #user{
        nick     = RegInfo#reg_info.nick,
        password = RegInfo#reg_info.password,
        email    = RegInfo#reg_info.email,
        name     = RegInfo#reg_info.name,
        channel  = smtp
    }.