cave-wiki
=========

Translation of Crowther's original Adventure to Federated Wiki

We examine the original version of the original interactive fiction work
also known as Colossal Cave. The program text consists of two parts: a 
fortran program and a structured text file. We've converted most segments
of the text to a corresponding wiki with one page per adventure room.
We are just now imagining how federated game authoring and game play 
could be hosted on the federated wiki platform.

build
=====

Create a federated wiki flat-file site. Clone this repository as 
a directory adjacent to the pages file for the site. Run the 
page builder with this ruby command.

    ruby build.rb

If your new site has only these pages you can still find your way
through the cave by examining Recent Changes. Each room appears
as its shortened name. Click on any to start browsing.

play
====

We don't yet have the mechanisms to play the game. Each page includes
links to adjacent places accessable by navigational commands in
the original program. Some links invoke actions. These are noted.

Several addional dump pages enumerate phrases that would be
recognized or spoken in game play. These suggest the richness
of the experience available in this first ever adventure.

future
======

We'd like to perform similar transformation of the fortran program
itself. Phrases of ten or twenty lines realize the semantics
encoded among the integers in the text file. This would be much 
easier to read if goto statements became hyperlinks and integer
arguments to the SPEAK command were annotated with the words
that would be spoken. This is within reach for our simple build.rb.

We'd also like to bring adventure to life within the context of
federated wiki. We have the places represented. We need similar
prepresentation for things and the actors that give them life.

Imagine if a player forked pages with game state into browser
local storage. The thinks at hand would be in the page lineup.
Long term play state would be in the brower. And the play
landscape would be federated among all the sites contributing
to the federated game.

literature
==========

We're more interested in the literature of programming than 
that of interactive fiction. Crowther's original code is worthy
of study. Knuth recognized this and cast a slightly later
version in his own literate style. Both poked against the
limitations of text files. We see wiki as a fully general
information format which lends itself better to programming
than formats available to Crowthers or Knuth. Federated
wiki promises even more open-ended extensibility to a 
community of authors. 
