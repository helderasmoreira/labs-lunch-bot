# Labs Lunch Bot
A Slack Bot to help the Triggerise Labs team rate their weekly team lunch place.

## Usage

The idea is for one of us to open up the voting, set the owner and in the next 60 minutes everyone can cast their vote.

We can then see list the votes and the bot will calculate the average automatically (it can be overwritten for cases where we don't have all the votes but know the average), color code it accordingly and also show everyone's votes.

![alt tag](https://raw.githubusercontent.com/heldersantosmoreira/labs-lunch-evaluator/master/gif/labs-lunch-bot.gif?token=AAd8Sv3FLdS677r80wNuhwfPDMJgWVoeks5YBp4pwA%3D%3D)

## Global commands

(can be used without mention)

`list` - List all the restaurants we classified so far by (ignoring any ongoing votings), ordered by timestamp.

`rank` - List all the restaurants we classified so far (ignoring any ongoing votings), ordered by descending vote average.

`new-vote` - Start a new vote for a restaurant. The new vote will be available for  minutes. Usage: `new-vote <name>`

`rename` - Rename the current voting. Usage: `rename <new-name>`

`set-owner` - Updates the owner (the person who decided on the restaurant) for the current vote. Usage: `set-owner <owner>`

`current` - Shows the current voting going on, if any. Also displays the current time remaining in minutes and number of votes so far. Usage: `current`

`vote` - Cast your vote for the current vote. If you do it multiple times within the time the voting is open, your vote will be overwritten. Usage: `vote <digit>`

## Other commands

(need to mention the bot username)

`help` - Shows help information

`hi` - Says hello

## Future ideas

- Specific user stats: his average vote, maximum, minimum, etc;
- Some rake tasks to make modifying the data file easier;
  - Export file
  - Delete entry
  - ...
