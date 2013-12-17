'use strict'

###
  We set up the app with 3 main routes: login, lobby, and room
###
angular.module('AgilePoker', ['pubnub.angular.service'])
  .config ($routeProvider) ->
    $routeProvider
      .when '/lobby',
        templateUrl: 'views/lobby.html'
        controller: 'LobbyCtrl'
      .when '/login',
        templateUrl: 'views/login.html'
        controller: 'LoginCtrl'
      .when '/rooms/:id',
        templateUrl: 'views/room.html'
        controller: 'RoomCtrl'
      .otherwise
        redirectTo: '/login'

###
  The login controller is responsible for initializing PubNub
  with the specified user id and directing the user to the Lobby
###
angular.module('AgilePoker')
  .controller 'LoginCtrl', ($scope, $rootScope, $location, PubNub) ->
    $rootScope.data ||= {}
    $scope.data ||= {}
    $scope.data.username = 'Anonymous ' + Math.floor(Math.random() * 1000)

    $scope.join = ->
      PubNub.init({
        subscribe_key : 'sub-c-45d9072c-b7df-11e2-bfb6-02ee2ddab7fe'
        publish_key   : 'pub-c-8715dc2e-2ee3-49ac-9dc5-410b6a282723'
        uuid          : Math.floor(Math.random() * 1000000) + '__' + $scope.data.username
      })
      $rootScope.data.username = $scope.data.username
      $location.path '/lobby'

###
  The Chat service encapsulates chat functionality into an
  easily include-able form.
###
ChatService =
  init: ($scope, $location, PubNub, room) ->
    $scope.sendChat = ->
      if $scope.data.message
        PubNub.ngPublish
          channel: room
          message:
            username: $scope.data.username
            message: $scope.data.message
        $scope.data.message = ''

    $scope.$on PubNub.ngMsgEv(room), (ngEvent, payload) ->
      history = "[" + payload.message.username + "] " + payload.message.message + "\n" + $('#chat_history').html()
      $('#chat_history').html(history)

    $scope.$on PubNub.ngPrsEv(room), ->
      $scope.$apply -> $scope.users = PubNub.map PubNub.ngListPresence(room), (x) -> x.replace(/\w+__/, "")

    $scope.logout = (path) -> $location.path(path) if path
    $scope.leave  = (path) ->
      PubNub.ngUnsubscribe({channel:room})
      $location.path(path) if path

    PubNub.ngSubscribe {channel: room}
    PubNub.ngHistory   {channel: room, count:500}
    PubNub.ngHereNow   {channel: room}

###
  The lobby controller
###
angular.module('AgilePoker')
  .controller 'LobbyCtrl', ($scope, $rootScope, $location, PubNub) ->
    $location.path '/login' unless $rootScope.data
    $scope.init = ->
      $scope.data = {}
      $scope.data.room = 'lobby'
      $scope.data.room_ctrl = '$lobby$ctrl'
      $scope.data.room_chat = '$lobby$chat'
      $scope.data.username = $rootScope.data?.username
      $scope.data.rooms ||= []

      PubNub.ngSubscribe {channel: $scope.data.room_ctrl}
      PubNub.ngHistory   {channel: $scope.data.room_ctrl, count:500}

      ChatService.init($scope, $location, PubNub, $scope.data.room_chat)

      $scope.$on PubNub.ngMsgEv($scope.data.room_ctrl), (ngEvent, payload) ->
        unless payload && _($scope.data.rooms).find( (x) -> (x.name == payload.message.room.name) )
          $scope.$apply -> $scope.data.rooms.push payload.message.room

    $scope.createRoom = ->
      if $scope.data.new_room.name
        message =
          type: 'create_room'
          username: $scope.data.username
          room: $scope.data.new_room

        ### Publish to the control channel to "create" the room ###
        PubNub.ngPublish
          channel: $scope.data.room_ctrl
          message: message

        ### Publish to the lobby chat channel to notify users of the room creation ###
        PubNub.ngPublish
          channel: $scope.data.room_chat
          message:
            username: 'RoomBot'
            message: $scope.data.username + " just created room '<a href=\"#/rooms/" + $scope.data.new_room.name + "\">" + $scope.data.new_room.name + "</a>'"

        ### Publish to the admin channel to initialize the room administrator ###
        PubNub.ngPublish
          channel: $scope.data.new_room.name + '$admn'
          message: message

        ### Publish to the room chat channel to welcome users ###
        PubNub.ngPublish
          channel: $scope.data.new_room.name + '$chat'
          message:
            username: 'RoomBot'
            message: "Welcome to '" + $scope.data.new_room.name + "'"

        $scope.data.showCreate = false

    $scope.init()


angular.module('AgilePoker')
  .controller 'RoomCtrl', ($scope, $rootScope, $routeParams, $location, PubNub) ->
    $location.path '/join' unless $rootScope.data

    $scope.init = ->
      $scope.data ||= {}
      $scope.data.room       = $routeParams.id
      $scope.data.room_lobby = '$lobby$ctrl'
      $scope.data.room_admn  = $routeParams.id + '$admn'
      $scope.data.room_ctrl  = $routeParams.id + '$ctrl'
      $scope.data.room_chat  = $routeParams.id + '$chat'
      $scope.data.username   = $rootScope.data?.username
      $scope.data.votes = {}
      $scope.data.votevalues = [ 0, '½', 1, 2, 3, 5, 8, 13, 20, 40 ]
      $scope.data.myvote = null
      $scope.data.reveal = false
      $('#chat_history').val('')

      PubNub.ngSubscribe {channel:$scope.data.room_ctrl}
      PubNub.ngSubscribe {channel:$scope.data.room_admn}

      ###
	      There are a few types of messages: admin (create/reveal),
	      control (enter/leave/vote), and chat (handled by ChatService)
      ###
      $scope.$on PubNub.ngMsgEv($scope.data.room_ctrl), (ngEvent, payload) ->
        if payload.message.type == 'vote' && !$scope.data.reveal
          $scope.$apply ->
            $scope.data.myvote = payload.message.value if payload.message.username == $scope.data.username
            $scope.data.votes[payload.message.username] = payload.message

      $scope.$on PubNub.ngMsgEv($scope.data.room_admn), (ngEvent, payload) ->
        if payload.message.type == 'create_room'
          $scope.$apply -> $scope.data.admin = payload.message.username

        if payload.message.type == 'reset'
          $scope.$apply ->
            $scope.data.reveal = null
            $scope.data.consensus = null
            $scope.data.consensus_value = null
            $scope.data.votes  = {}
            history = "***Voting was reset.\n" + $('#chat_history').html()
            $('#chat_history').html(history)

        if payload.message.type == 'reveal'
          $scope.data.votes = payload.message.votes
          $scope.$apply ->
            $scope.data.reveal = true
            $scope.data.consensus = payload.message.consensus
            $scope.data.consensus_value = payload.message.consensus_value

            if payload.message.votes
              votes = _(payload.message.votes).map( (vote) -> vote.username + " voted " + vote.value ).join(", ")
              history = "***Votes revealed: " + votes + "\n" + $('#chat_history').html()
              $('#chat_history').html(history)

      PubNub.ngHistory {channel:$scope.data.room_ctrl,count:500}
      PubNub.ngHistory {channel:$scope.data.room_admn,count:500}

      ChatService.init($scope, $location, PubNub, $scope.data.room_chat)

    ###
      Voting entails publishing a vote message including your username
      on the control channel
    ###
    $scope.vote = (value) ->
      PubNub.ngPublish
        channel: $scope.data.room_ctrl
        message:
          type: 'vote'
          value: value
          username: $scope.data.username

    ###
      Reveal entails publishing a reveal message on the admin channel with the
      full voting results
    ###
    $scope.reveal = ->
      _($scope.data.votes).forEach (x) -> x.displayvalue = x.value
      ### Compute consensus with underscore 'countBy' and taking item with max count ###
      voteCounts = _($scope.data.votes).countBy (x) -> x.value
      max_key = null
      max_val = -1
      _(voteCounts).forEach (count, value) ->
        if (count == max_val)
          ### unset max_key in case of a collision ###
          max_key = null
        else
          if (count > max_val)
            max_key = value
            max_val = count

      PubNub.ngPublish
        channel: $scope.data.room_admn
        message:
          type: 'reveal'
          votes: $scope.data.votes
          consensus: !!max_key
          consensus_value: if max_key then max_key else null
          username: $scope.data.username

    ###
      Reset entails publishing a reset message on the admin channel
    ###
    $scope.reset = ->
      PubNub.ngPublish
        channel: $scope.data.room_admn
        message:
          type: 'reset'

    $scope.isAdmin = ->
      !$scope.data.admin || ($scope.data.username == $scope.data.admin)

    $scope.takeAdmin = ->
      PubNub.ngPublish
        channel: $scope.data.room_admn
        message:
          type: 'create_room'
          username: $scope.data.username
          room: $scope.data.new_room

      PubNub.ngPublish
        channel: $scope.data.room_chat
        message:
          username: 'RoomBot'
          message: $scope.data.username + " just took 'admin'!"

    $scope.init()
