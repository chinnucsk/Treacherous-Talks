%%%-------------------------------------------------------------------
%%% @copyright
%%% Copyright (C) 2011 by Bermuda Triangle
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in
%%% all copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%%% THE SOFTWARE.
%%% @end
%%%-------------------------------------------------------------------

-module(message_util).

-include_lib("datatypes/include/bucket.hrl").
-include_lib("datatypes/include/message.hrl").

-export([get_message/2]).


%% -----------------------------------------------------------------------------
%% @doc
%% Gets the message with the given message id
%% @end
%% -----------------------------------------------------------------------------
-spec get_message(MessageId::integer(), Bucket::binary()) ->
          {ok, Message::term()} | {error, Error::term()}.
get_message(MessageId, Bucket) ->
    case db:get(Bucket, list_to_binary(MessageId), [{r,1}]) of
        {ok, DBObj} ->
            Message = db_obj:get_value(DBObj),
            {ok, Message};
        {error, Error} ->
            {error, Error}
    end.




