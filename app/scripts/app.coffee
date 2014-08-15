# Annotated Source Code for the PubNub AngularJS library.
# Welcome! Thank you for reading this documentation - if you have any feedback or suggestions, please file a GitHub issue and we'll take a look right away!

# We love strict mode.

'use strict'

# Set up an Angular [module](https://docs.angularjs.org/guide/module). Notice the identifier `pubnub.angular.service`, used when declaring a [dependency](https://docs.angularjs.org/guide/di) on the PubNub Angular library.

# We set up the Agile Poker app with 3 main [routes](https://docs.angularjs.org/api/ngRoute/service/$route): login, lobby, and room:

angular.module('AgilePoker', ['pubnub.angular.service'])
  .config ($routeProvider) ->
    $routeProvider
# - A page to find out more about the application
      .when '/intro',
        templateUrl: 'views/intro.html'
        controller: 'IntroCtrl'
# - The lobby page is where users can chat, join an existing room, or create a new room.
      .when '/lobby',
        templateUrl: 'views/lobby.html'
        controller: 'LobbyCtrl'
# - The login page is where people can see a basic description of the app and sign in.
      .when '/login',
        templateUrl: 'views/login.html'
        controller: 'LoginCtrl'
# - The room page is where users can discuss and vote on a task.
      .when '/rooms/:id',
        templateUrl: 'views/room.html'
        controller: 'RoomCtrl'
      .otherwise
        redirectTo: '/login'

# The login [controller](https://docs.angularjs.org/guide/controller) is responsible for initializing PubNub with the specified user id and directing the user to the Lobby.
angular.module('AgilePoker')
  .controller 'LoginCtrl', ($scope, $rootScope, $location, PubNub) ->
    $rootScope.data ||= {}
    $scope.data ||= {}
    $scope.data.username = 'Anonymous ' + Math.floor(Math.random() * 1000)

# For joining a room, PubNub is [initialized](http://www.pubnub.com/docs/javascript/api/reference.html#init) with a [`subscribe_key`](http://www.pubnub.com/docs/javascript/api/reference.html#init), [`publish_key`](http://www.pubnub.com/docs/javascript/api/reference.html#init), and [`uuid`](http://www.pubnub.com/docs/javascript/api/reference.html#init). 
    $scope.join = ->
      PubNub.init({
        subscribe_key : 'sub-c-45d9072c-b7df-11e2-bfb6-02ee2ddab7fe'
        publish_key   : 'pub-c-8715dc2e-2ee3-49ac-9dc5-410b6a282723'
        # This assigns a random username if a username is not specified by the user
        uuid          : Math.floor(Math.random() * 1000000) + '__' + $scope.data.username
      })
      $rootScope.data.username = $scope.data.username
      $location.path '/lobby'

# The Chat service encapsulates chat functionality into an easily include-able form.
ChatService =
  init: ($scope, $location, PubNub, room) ->
    $scope.sendChat = ->
      if $scope.data.message
# The `ngPublish` function is used to send messages in a channel.
        PubNub.ngPublish
# The channel is the room.
          channel: room
# The message published in the channel is the username of the sender, and the text the user sends.
          message:
            username: $scope.data.username
            message: $scope.data.message
        $scope.data.message = ''

# The channel (the current room) listens for a message event. The history is displayed as '[username]: message'.
    $scope.$on PubNub.ngMsgEv(room), (ngEvent, payload) ->
      history = "[" + payload.message.username + "] " + payload.message.message + "\n" + $('#chat_history').html()
      $('#chat_history').html(history)

# We listen for presence events in the room with the ngPresEv function and list the users in the room with ngListPresence. 
    $scope.$on PubNub.ngPrsEv(room), ->
      $scope.$apply -> $scope.users = PubNub.map PubNub.ngListPresence(room), (x) -> x.replace(/\w+__/, "")

# Logging out of a room is accomplished by using the ngUnsubscribe function.
    $scope.logout = (path) -> $location.path(path) if path
    $scope.leave  = (path) ->
      PubNub.ngUnsubscribe({channel:room})
      $location.path(path) if path

# ngSubscribe allows us to join a channel (room) 
    PubNub.ngSubscribe {channel: room}
# ngHistory allows us to show the history in a channel and specify a limit of history displayed
    PubNub.ngHistory   {channel: room, count:500}
# ngHere now gets the current users in a channel (room)
    PubNub.ngHereNow   {channel: room}

# The lobby controller
angular.module('AgilePoker')
  .controller 'IntroCtrl', ($scope, $rootScope, $location, PubNub) ->
    $location.path '/intro' unless $rootScope.data
    $scope.init = ->
      $scope.data = {}
      $scope.data.room = 'intro'
      $scope.data.room_ctrl = '$intro$ctrl'

# The lobby controller
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

# Creating a room requires a room name 
    $scope.createRoom = ->
      if $scope.data.new_room.name
        message =
          type: 'create_room'
          username: $scope.data.username
          room: $scope.data.new_room

        # Publish to the control channel to "create" the room 
        PubNub.ngPublish
          channel: $scope.data.room_ctrl
          message: message

        # Publish to the lobby chat channel to notify users of the room creation 
        PubNub.ngPublish
          channel: $scope.data.room_chat
          message:
            username: 'RoomBot'
            message: $scope.data.username + " just created room '<a href=\"#/rooms/" + $scope.data.new_room.name + "\">" + $scope.data.new_room.name + "</a>'"

        # Publish to the admin channel to initialize the room administrator 
        PubNub.ngPublish
          channel: $scope.data.new_room.name + '$admn'
          message: message

        # Publish to the room chat channel to welcome users 
        PubNub.ngPublish
          channel: $scope.data.new_room.name + '$chat'
          message:
            username: 'RoomBot'
            message: "Welcome to '" + $scope.data.new_room.name + "'"

        $scope.data.showCreate = false

    $scope.init()

# The Room Controller
angular.module('AgilePoker')
  .controller 'RoomCtrl', ($scope, $rootScope, $routeParams, $location, PubNub) ->
    $location.path '/join' unless $rootScope.data

# Initialize the lobby, admin, room controller, room chat, 
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

      # There are a few types of messages: admin (create/reveal), control (enter/leave/vote), and chat (handled by ChatService)
      $scope.$on PubNub.ngMsgEv($scope.data.room_ctrl), (ngEvent, payload) ->
        if payload.message.type == 'vote' && !$scope.data.reveal
          $scope.$apply ->
            $scope.data.myvote = payload.message.value if payload.message.username == $scope.data.username
            $scope.data.votes[payload.message.username] = payload.message

      $scope.$on PubNub.ngMsgEv($scope.data.room_admn), (ngEvent, payload) ->
        if payload.message.type == 'create_room'
          $scope.$apply -> $scope.data.admin = payload.message.username

# Reset the voting
        if payload.message.type == 'reset'
          $scope.$apply ->
            $scope.data.reveal = null
            $scope.data.consensus = null
            $scope.data.consensus_value = null
            $scope.data.votes  = {}
            history = "***Voting was reset.\n" + $('#chat_history').html()
            $('#chat_history').html(history)

# Reveal the voting results
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

    # Voting entails publishing a vote message including your username on the control channel
    $scope.vote = (value) ->
      PubNub.ngPublish
        channel: $scope.data.room_ctrl
        message:
          type: 'vote'
          value: value
          username: $scope.data.username

    # Reveal entails publishing a reveal message on the admin channel with the full voting results
    $scope.reveal = ->
      _($scope.data.votes).forEach (x) -> x.displayvalue = x.value
      # Compute consensus with underscore 'countBy' and taking item with max count
      voteCounts = _($scope.data.votes).countBy (x) -> x.value
      max_key = null
      max_val = -1
      _(voteCounts).forEach (count, value) ->
        if (count == max_val)
          # unset max_key in case of a collision
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

    # Reset entails publishing a reset message on the admin channel
    $scope.reset = ->
      PubNub.ngPublish
        channel: $scope.data.room_admn
        message:
          type: 'reset'

    $scope.isAdmin = ->
      !$scope.data.admin || ($scope.data.username == $scope.data.admin)

# Take over admin position
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
