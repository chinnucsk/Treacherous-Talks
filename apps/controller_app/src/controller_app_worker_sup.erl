-module(controller_app_worker_sup).
-behaviour(supervisor).

%% API
-export([start_link/0, worker_count/0, worker_count/1]).

%% Supervisor callbacks
-export([init/1]).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, no_arg).

worker_count() ->
    service_worker_sup:worker_count(?MODULE).

worker_count(Count) ->
    service_worker_sup:worker_count(?MODULE, controller_app,
                                    controller_app_worker, Count).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================
init(no_arg) ->
    io:format ("[~p] starting ~p~n", [?MODULE, self()]),
    Workers = service_worker_sup:create_childspec(
                controller_app, controller_app_workers, controller_app_worker),
    {ok, { {one_for_one, 5, 10}, Workers } }.

