(function() {
  'use strict';
  /*
    We set up the app with 3 main routes: login, lobby, and room
  */

  var ChatService;

  angular.module('AgilePoker', ['pubnub.angular.service']).config(function($routeProvider) {
    return $routeProvider.when('/lobby', {
      templateUrl: 'views/lobby.html',
      controller: 'LobbyCtrl'
    }).when('/login', {
      templateUrl: 'views/login.html',
      controller: 'LoginCtrl'
    }).when('/rooms/:id', {
      templateUrl: 'views/room.html',
      controller: 'RoomCtrl'
    }).otherwise({
      redirectTo: '/login'
    });
  });

  /*
    The login controller is responsible for initializing PubNub
    with the specified user id and directing the user to the Lobby
  */


  angular.module('AgilePoker').controller('LoginCtrl', function($scope, $rootScope, $location, PubNub) {
    $rootScope.data || ($rootScope.data = {});
    $scope.data || ($scope.data = {});
    $scope.data.username = 'Anonymous ' + Math.floor(Math.random() * 1000);
    return $scope.join = function() {
      PubNub.init({
        subscribe_key: 'sub-c-45d9072c-b7df-11e2-bfb6-02ee2ddab7fe',
        publish_key: 'pub-c-8715dc2e-2ee3-49ac-9dc5-410b6a282723',
        uuid: Math.floor(Math.random() * 1000000) + '__' + $scope.data.username
      });
      $rootScope.data.username = $scope.data.username;
      return $location.path('/lobby');
    };
  });

  /*
    The Chat service encapsulates chat functionality into an
    easily include-able form.
  */


  ChatService = {
    init: function($scope, $location, PubNub, room) {
      $scope.sendChat = function() {
        if ($scope.data.message) {
          PubNub.ngPublish({
            channel: room,
            message: {
              username: $scope.data.username,
              message: $scope.data.message
            }
          });
          return $scope.data.message = '';
        }
      };
      $scope.$on(PubNub.ngMsgEv(room), function(ngEvent, payload) {
        var history;
        history = "[" + payload.message.username + "] " + payload.message.message + "\n" + $('#chat_history').html();
        return $('#chat_history').html(history);
      });
      $scope.$on(PubNub.ngPrsEv(room), function() {
        return $scope.$apply(function() {
          return $scope.users = PubNub.map(PubNub.ngListPresence(room), function(x) {
            return x.replace(/\w+__/, "");
          });
        });
      });
      $scope.logout = function(path) {
        if (path) {
          return $location.path(path);
        }
      };
      $scope.leave = function(path) {
        PubNub.ngUnsubscribe({
          channel: room
        });
        if (path) {
          return $location.path(path);
        }
      };
      PubNub.ngSubscribe({
        channel: room
      });
      PubNub.ngHistory({
        channel: room,
        count: 500
      });
      return PubNub.ngHereNow({
        channel: room
      });
    }
  };

  /*
    The lobby controller
  */


  angular.module('AgilePoker').controller('LobbyCtrl', function($scope, $rootScope, $location, PubNub) {
    if (!$rootScope.data) {
      $location.path('/login');
    }
    $scope.init = function() {
      var _base, _ref;
      $scope.data = {};
      $scope.data.room = 'lobby';
      $scope.data.room_ctrl = '$lobby$ctrl';
      $scope.data.room_chat = '$lobby$chat';
      $scope.data.username = (_ref = $rootScope.data) != null ? _ref.username : void 0;
      (_base = $scope.data).rooms || (_base.rooms = []);
      PubNub.ngSubscribe({
        channel: $scope.data.room_ctrl
      });
      PubNub.ngHistory({
        channel: $scope.data.room_ctrl,
        count: 500
      });
      ChatService.init($scope, $location, PubNub, $scope.data.room_chat);
      return $scope.$on(PubNub.ngMsgEv($scope.data.room_ctrl), function(ngEvent, payload) {
        if (!(payload && _($scope.data.rooms).find(function(x) {
          return x.name === payload.message.room.name;
        }))) {
          return $scope.$apply(function() {
            return $scope.data.rooms.push(payload.message.room);
          });
        }
      });
    };
    $scope.createRoom = function() {
      var message;
      if ($scope.data.new_room.name) {
        message = {
          type: 'create_room',
          username: $scope.data.username,
          room: $scope.data.new_room
        };
        /* Publish to the control channel to "create" the room*/

        PubNub.ngPublish({
          channel: $scope.data.room_ctrl,
          message: message
        });
        /* Publish to the lobby chat channel to notify users of the room creation*/

        PubNub.ngPublish({
          channel: $scope.data.room_chat,
          message: {
            username: 'RoomBot',
            message: $scope.data.username + " just created room '<a href=\"#/rooms/" + $scope.data.new_room.name + "\">" + $scope.data.new_room.name + "</a>'"
          }
        });
        /* Publish to the admin channel to initialize the room administrator*/

        PubNub.ngPublish({
          channel: $scope.data.new_room.name + '$admn',
          message: message
        });
        /* Publish to the room chat channel to welcome users*/

        PubNub.ngPublish({
          channel: $scope.data.new_room.name + '$chat',
          message: {
            username: 'RoomBot',
            message: "Welcome to '" + $scope.data.new_room.name + "'"
          }
        });
        return $scope.data.showCreate = false;
      }
    };
    return $scope.init();
  });

  angular.module('AgilePoker').controller('RoomCtrl', function($scope, $rootScope, $routeParams, $location, PubNub) {
    if (!$rootScope.data) {
      $location.path('/join');
    }
    $scope.init = function() {
      var _ref;
      $scope.data || ($scope.data = {});
      $scope.data.room = $routeParams.id;
      $scope.data.room_lobby = '$lobby$ctrl';
      $scope.data.room_admn = $routeParams.id + '$admn';
      $scope.data.room_ctrl = $routeParams.id + '$ctrl';
      $scope.data.room_chat = $routeParams.id + '$chat';
      $scope.data.username = (_ref = $rootScope.data) != null ? _ref.username : void 0;
      $scope.data.votes = {};
      $scope.data.votevalues = [0, '½', 1, 2, 3, 5, 8, 13, 20, 40];
      $scope.data.myvote = null;
      $scope.data.reveal = false;
      $('#chat_history').val('');
      PubNub.ngSubscribe({
        channel: $scope.data.room_ctrl
      });
      PubNub.ngSubscribe({
        channel: $scope.data.room_admn
      });
      /*
      	      There are a few types of messages: admin (create/reveal),
      	      control (enter/leave/vote), and chat (handled by ChatService)
      */

      $scope.$on(PubNub.ngMsgEv($scope.data.room_ctrl), function(ngEvent, payload) {
        if (payload.message.type === 'vote' && !$scope.data.reveal) {
          return $scope.$apply(function() {
            if (payload.message.username === $scope.data.username) {
              $scope.data.myvote = payload.message.value;
            }
            return $scope.data.votes[payload.message.username] = payload.message;
          });
        }
      });
      $scope.$on(PubNub.ngMsgEv($scope.data.room_admn), function(ngEvent, payload) {
        if (payload.message.type === 'create_room') {
          $scope.$apply(function() {
            return $scope.data.admin = payload.message.username;
          });
        }
        if (payload.message.type === 'reset') {
          $scope.$apply(function() {
            var history;
            $scope.data.reveal = null;
            $scope.data.consensus = null;
            $scope.data.consensus_value = null;
            $scope.data.votes = {};
            history = "***Voting was reset.\n" + $('#chat_history').html();
            return $('#chat_history').html(history);
          });
        }
        if (payload.message.type === 'reveal') {
          $scope.data.votes = payload.message.votes;
          return $scope.$apply(function() {
            var history, votes;
            $scope.data.reveal = true;
            $scope.data.consensus = payload.message.consensus;
            $scope.data.consensus_value = payload.message.consensus_value;
            if (payload.message.votes) {
              votes = _(payload.message.votes).map(function(vote) {
                return vote.username + " voted " + vote.value;
              }).join(", ");
              history = "***Votes revealed: " + votes + "\n" + $('#chat_history').html();
              return $('#chat_history').html(history);
            }
          });
        }
      });
      PubNub.ngHistory({
        channel: $scope.data.room_ctrl,
        count: 500
      });
      PubNub.ngHistory({
        channel: $scope.data.room_admn,
        count: 500
      });
      return ChatService.init($scope, $location, PubNub, $scope.data.room_chat);
    };
    /*
      Voting entails publishing a vote message including your username
      on the control channel
    */

    $scope.vote = function(value) {
      return PubNub.ngPublish({
        channel: $scope.data.room_ctrl,
        message: {
          type: 'vote',
          value: value,
          username: $scope.data.username
        }
      });
    };
    /*
      Reveal entails publishing a reveal message on the admin channel with the
      full voting results
    */

    $scope.reveal = function() {
      var max_key, max_val, voteCounts;
      _($scope.data.votes).forEach(function(x) {
        return x.displayvalue = x.value;
      });
      /* Compute consensus with underscore 'countBy' and taking item with max count*/

      voteCounts = _($scope.data.votes).countBy(function(x) {
        return x.value;
      });
      max_key = null;
      max_val = -1;
      _(voteCounts).forEach(function(count, value) {
        if (count === max_val) {
          /* unset max_key in case of a collision*/

          return max_key = null;
        } else {
          if (count > max_val) {
            max_key = value;
            return max_val = count;
          }
        }
      });
      return PubNub.ngPublish({
        channel: $scope.data.room_admn,
        message: {
          type: 'reveal',
          votes: $scope.data.votes,
          consensus: !!max_key,
          consensus_value: max_key ? max_key : null,
          username: $scope.data.username
        }
      });
    };
    /*
      Reset entails publishing a reset message on the admin channel
    */

    $scope.reset = function() {
      return PubNub.ngPublish({
        channel: $scope.data.room_admn,
        message: {
          type: 'reset'
        }
      });
    };
    $scope.isAdmin = function() {
      return !$scope.data.admin || ($scope.data.username === $scope.data.admin);
    };
    $scope.takeAdmin = function() {
      PubNub.ngPublish({
        channel: $scope.data.room_admn,
        message: {
          type: 'create_room',
          username: $scope.data.username,
          room: $scope.data.new_room
        }
      });
      return PubNub.ngPublish({
        channel: $scope.data.room_chat,
        message: {
          username: 'RoomBot',
          message: $scope.data.username + " just took 'admin'!"
        }
      });
    };
    return $scope.init();
  });

}).call(this);
