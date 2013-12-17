# Agile Poker

A collaborative project estimation tool written with AngularJS and
powered by PubNub global real-time communication infrastructure.

For developers who have done software planning in an Agile process,
this application should feel familiar. The goal of the application is
to provide a collaborative space for developers to discuss, vote, and
reach consensus on the complexity of a task. For example:

* Leader: "The next task under discussion is WIDGET-193, adding a 'like' button to the widget interface"
* Developer A: "Does this include the 'like' frontend and backend?"
* Leader: "Yes - good clarification. Any other questions?"
* Developers A, B, C, D: "Nope. All set!"
* Leader: "OK, let's vote."
* Developer D: <casts hidden vote>
* Developer B: <casts hidden vote>
* Developer C: <casts hidden vote>
* Developer A: <casts hidden vote>
* Leader: "Ok, revealing the vote!"
* (The vote is A:10, B:10, C:8, D:13)
* Leader: "Looks like we have a consensus value of 10. Developers C and D, are you in agreement with that?"
* (Developers C and D have a chance to explain)
* Leader: "OK, looks like this is a 10. On to the next task!"
* (The leader could also reset the vote and start over)

The Agile Poker application is a collaborative application that
uses AngularJS and Bootstrap to provide a modern, responsive user
interface for web and mobile, and PubNub to provide real-time
communications and event storage functionality.

# The Planning Process

Users choose a handle before entering the application (to make things
easy, a random one is provided). Users may sign out and choose a new
handle at any time, and previous actions will still be recorded
under the previous handle.

Upon entering the application, users are taken to the Lobby where they
are able to chat, create new planning rooms, or enter an existing planning
room.

Planning rooms are where the real work of the application is done.
Any user can create a planning room. Upon creating the room, the user
is given the Admin privilege by default. This means that they can close
and/or reset the vote at any time.

A group of users enters a planning room to discuss the item that they will
estimate. Users may cast and change their votes at any time during the
discussion; votes will be hidden from view until the Admin user closes the
vote and reveals the result. (The secret vote is to avoid biasing group
opinion.)

The Admin user closes the vote and displays the winning selection by clicking
a button in the administrative controls. When the vote is closed, the application
counts all of the results to see if one selection has more votes than any other.
If such a winner exists, that result will be deemed the "consensus" value. If not,
the result is "no consensus" - the Admin attempt consensus again by resetting
the vote and reopening discussion.

In the spirit of collaboration, the Admin privilege is not strictly enforced;
any user may "take" the Admin privilege at any time.

