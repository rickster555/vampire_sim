###
source file: vampire_sim.coffee
author: RcDarwin (c) 2014-04-07
dependencies: ???
###

###
** Generate a tree of sorcerous vampires, assuming a genLength of say 20 yrs,
** (It takes years to learn the ritual to a level that 'guarantees' success,
** and then there is the seduction of and trust-building with the apprentice.)
** 
**
** The tree looks like this:
**		v0
**		|
**		|
**		v1--------------X
**		|		            |
**		|		            |
**		v2------X	      v3------X
**		|	     |	      |	      |
**		|	     |	      |	      |
**		v4	   v5	      v6      v7
**
** v0 creates v1, v2, v4; v1 creates v3, v6; v2 creates v5; v3 creates v7,...
** In general, vertical line is successive creations by the topmost vampire: the X to rightwards
** marks the start of another such line of creation from the given sibling node.
**
###

# fake constants

# add i to the Enum function,
# in back-tick fashion...this one from rauschma/enums, on github 13 Jul 2011
`function Enum (constantsList) {var i = 0; for (var c in constantsList) {this[constantsList[c]] = i; i += 1;} this.allValues = constantsList;}`

Enum::value = (i) ->
	@allValues[i]

Enum::values = () ->
	@allValues


`var decilog = function log10(x) {
	var max = Math.abs(x), mp10 = Math.pow(10, -9);
	if (max < mp10) {
		return 0.0;
	}
	else {
		return Math.log (x) / Math.LN10;
	}
};

// Math10 = new Math();
// Math10.prototype.log10 = decilog;`


States = new Enum ['NONE','ALIVE','UNDEAD','DEAD','ROOT','RIT_FAILED','RIT_FUMBLED','HUNTED','SLAIN']

Rolls = new Enum ['CRITICAL','SPECIAL','HIT','MISS','BOLLIX','FUMBLE']

vTree = new Array()

class Vampire
	constructor: (nx, yoc, parx = ((reduce2 nx) - 1) / 2) ->
		@nx = nx
		@yoc = yoc	# year when change should occur if master is available
		@parx = parx	# index of master who changed this one
		@parent = @calcCode() + @parx.toString()
		# other properties
		@IDx = (idiv nx, 2)
		@ID = @calcCode() + @IDx.toString()	# node nx==4 (vampire )has ID V2; node nx==5 (chain-root) has ID R2
		@nomen = ""
		#
		@yob = @yoc - dice 3, 10, 15
		@life = @yoc - @yob	# age when change should occur...
		@status = States.ALIVE
		@unlife = 0	# duration of unlife
		@life2 = (dice 5,12,10) # life after ritual IF appr dies and revives as breather
		@yod = @yoc + @life2	# assume appr lives this much longer as a breather
		@deathcause = States.ALIVE	# well, it's true...
		#
		@Enchant = (dice 3, 10, 80)
		@spawnlist = [ ]
		#
		@left = @nx * 2		# integers as pointers...
		@right = @nx * 2 + 1
		#.
	
	# we just show the even-indexed nodes (the real vampires), not the subchain roots
	printMe: ( ) ->
		vamp = vTree[@nx]
		truedeath = (if @deathcause > States.ROOT then "unlife: #{@unlife}, died: #{@yod}, reason: #{States.value @deathcause}, " else "still a vampire...,")
		console.log "nx: #{vamp.nx}, ID: #{vamp.ID}, Name: #{vamp.nomen}, born: #{vamp.yob}, changed: #{vamp.yoc}, " + truedeath +
			", parent: #{vamp.parent}, status: #{States.value vamp.status}, " +
			"\nleftNode: #{vamp.left}, rightNode: #{vamp.right}\n"
			
	calcCode: ( ) ->
		if @nx % 2 is 0 then "V" else "R"
		#.
		
	handleEnchant: ( ) ->
		chain = vTree[@nx + 1]
		console.log "#{chain}"
		master = vTree[getpx @nx]
		mark = master.Enchant + (dice 3,10)	# adj for master's Ceremony
		switch rollGrade (die 100, mark)
			when Rolls.CRITICAL, Rolls.SPECIAL, Rolls.HIT
				@status = States.UNDEAD
				@deathcause  = States.NONE
				@unlife = 4096
				@yod = @yoc + @unlife
			when Rolls.MISS, Rolls.BOLLIX
				@status = States.RIT_FAILED
				@deathcause = States.RIT_FAILED
				@unlife = 0	
				@yod = @yoc
				vamp.status = try_resurrect (@nx)	# set @status to ALIVE | NONE
			when Rolls.FUMBLE
				@status = States.NONE
				@deathcause = States.RIT_FUMBLED
				@unlife = 0	
				@yod = @yoc
			#.
		console.log "in handleEnchant(): this-nx is #{@nx}, this-status is #{States.value @status}, " +
			"chain-status is #{States.value chain.status}"
		if @status is States.UNDEAD then chain.status = States.ROOT else chain.status = States.NONE
		#.
		
	hazardTruedeath: ( ) ->
		# in the first few years, new vampire is at risk for doing something fatally stupid
		# create array of declining probabilities for the mishap
		obj = new Array()
		for n in[2..9]
			obj[n] = Math.floor(1.0 - (decilog (n)) * 1000)
		# now pick one stupid move>>>
		crisisYear = (die 8) + 1
		if die 1000 <= obj[crisisYear]
			@status = States.HUNTED
		# possibility of a duel...based on data from French army ca 1700
		for n in [1...@unlife]
			if die 1000 <= 3	# 3 not 6: surely vampires duel less often than army officers...
				@status = States.SLAIN
				break
		#.
		
	# end class
	
#
# index manipulation functions
#
reduce2 = (x) ->
	if x <= 1 then return 1
	while x % 2 is 0
		x /= 2
	x

idiv = (x,y) ->
	Math.floor (x / y)

getpx = (nx) ->
	nid = (idiv nx, 2)
	pid = (reduce2 nid) - 1
	if pid < 1 then pid = 1
	pid

#
# ancilliary functions for class Vampire
#
report = (nx) ->
	console.log " #{nx}, master is #{getpx nx}"
	vamp = vTree[nx]
	master = vTree[getpx nx]
	if (vamp.nx%2 is 0) && (vamp.deathcause isnt States.NONE)
		truedeath = "unlife: #{vamp.unlife}, died: #{vamp.yod}, reason: #{vamp.deathcause}, "
	else
		truedeath = "still a vampire..., "
		
	console.log "nx: #{vamp.nx} ID: #{vamp.ID} Name: #{vamp.nomen}\n" + 
		"born: #{vamp.yob}, changed: #{vamp.yoc}, status: #{States.value vamp.status},\n" + 
		truedeath + "parent is px: #{master.nx} ID: #{master.ID} Name: #{master.nomen}\n" + 
		"#{vamp.ID}'s spawn: #{vamp.spawnlist}\n"

alter = (vamp) ->
	master = vTree[getpx vamp.nx]
	if master.status isnt States.UNDEAD
		vamp.status = States.ALIVE
		vTree[vamp.nx + 1].status = States.NONE
		return
	vamp.nomen = getname (nx)
	vamp.handleEnchant()
	#.

getname = (nx) ->
	if nx is 1 then return "Halan"		# ca 1160 AR.
	if nx is 64 then return "Akchan"	# ca 1280 AR.
	names = ["Tsalchan", "Korewanna", "Leyssa", "Pengli", "Gwillam", "Serghir", "Roseib", "Ardhyr", "Feren", "dan-Shenti", "Huyo", "Patrishk", "Kerrys", "Gallen", "Robollyn", "Swikro", "Silkun", "Athorre", "Nafarris", "Gaunisen"]
	names[die 20]
	#.

# pretty rare for a god to resurrect a vampire candidate...!
# and we won't have many candidates trying again either.
# this is called from handleEnchant, when roll result is MISS or BOLLIX
#
try_resurrect = (vamp) ->
	vamp.status = (if die 100 <= die 3 then States.ALIVE else States.RIT_FAILED)
	if vamp.status is States.ALIVE
		@yod = @yoc + @life2
		@deathcause = States.ALIVE
		@unlife = 0
		#.
	#.
#
# dice functions
#
die = (hedra) ->
	Math.floor (Math.random( ) * hedra) + 1

dice = (num, hedra, adj = 0) ->
	sum = 0
	while num-- > 0
		sum += die (hedra)
	sum + adj

rollGrade = (roll, mark) ->
	crit = if mark > 9 then (idiv ((idiv mark, 10) + 1), 2.0) else 1
	spec = if mark > 7 then Math.round (mark / 5.0) else 1
	poor = spec + 80
	fumb = Math.round ((mark - 1) / 2.0) + 96
	
	if roll > mark	# M B F branch
		switch
			when roll >= fumb then Rolls.FUMBLE
			when roll >= poor then Rolls.BOLLIX
			else Rolls.MISS
	else
		switch
			when roll <= crit then Rolls.CRITICAL
			when roll <= spec then Rolls.SPECIAL
			else  Rolls.HIT
	#.


#
# Start here
#
baseYear = 1160	#  Halan transformed in 1160 AR.; he was born in 1088 AR.
trackYear  = baseYear	# to start with...
currentYear = 1520
genx = 0
genoflect = 1
genLength = 20 		# years
maxGens = 5
log2 = Math.log (2)
nid = 0
pid = 0



# Initialize
#
maxVamps = Math.pow(2, maxGens)
console.log "maxVamps: #{maxVamps}"
console.log "It is now #{currentYear} AR.\n"
# Store the vampire objects in the array, with pointers left and
# right to simulate a binary tree.
#
nx = 1
vTree[nx] = new Vampire nx, trackYear, undefined
vTree[nx].status = States.UNDEAD
vTree[nx].nomen = "Halan"
vTree[nx].parent = '?'
vTree[nx].ID = 'V0'
vTree[nx].life = 72
vTree[nx].yoc = 1160
vTree[nx].unlife = 4096
vTree[nx].printMe()
console.log "\n"

# Populate remainder of the array
#
nx = 2
while nx < maxVamps
	# check if it is time for next generation
	#
	mll = (Math.log(nx) / log2)
	genx = Math.floor(mll)
	if mll >= genoflect
		genoflect *= 2
		trackYear += genLength
	# console.log "trackYear: #{trackYear + genLength}"
	#
	newBirth = baseYear + genLength * genx
	vTree[nx] = new Vampire nx, newBirth
	vamp = vTree[nx]
	alter (vamp)
	# update parent's spawnlist
	#
	#  px is the node index of the original vampire--v0 spawns v1, v2, v4 ,v8,...
	#  we reduce2 nx, the node index of the latest spawn,
	#  until it becomes odd (first spawnlist element *is* odd, by design)
	#
	px = getpx nx
	master = vTree[px]
	
	# report vamp
	#8:54 PM 3/13/2014:
	# to avoid masking the spawnlist, I moved the log stmt after the printMe call.
	
	# handle the spawnlist...
	#
	if master.status isnt States.UNDEAD
		vamp.status = States.NONE
		vamp.spawnlist = null
	else
		adjEnchant = master.Enchant + dice 3, 10
		roll = die 100
		result = rollGrade roll, adjEnchant
		
		vamp.status = switch
			when result <= Rolls.HIT
				States.UNDEAD
			when result is Rolls.MISS || result is Rolls.BOLLIX
				try_resurrect (vamp)
			when result > Rolls.BOLLIX
				States.RIT_FUMBLE
			else States.NONE
		#
	# push the current vampire node to the parental vampire's spawnlist
	console.log "\n-->nx: #{nx}, master is #{master.nx}"
	if nx%2 is 0
		 # console.log "pushing #{vamp.ID} to #{master.ID}'s spawnlist..."
		master.spawnlist.push vamp.ID
		vamp.printMe()
	nx += 1
	
console.log "\n\nFinal Report on Spawn:"
# 10:45 AM 3/14/2014:
# replaced nid..px by function call getpx

nx = 1
px = (getpx nx)
report nx

nx = 2
while nx < maxVamps
	px = getpx nx
	if nx%2 is 0
		report nx
	nx += 1
	#.


# console.log "Ritual result: #{Rolls.value (result)}"


###
if vamp.status isnt States.UNDEAD
		vamp.deathcause = vamp.status	# typically HUNTED or SLAIN
		if vamp.unlife < currentYear - vamp.yoc
			vamp.yod = currentYear - (vamp.yoc + vamp.unlife)
###

# console.log "vampire nx is #{nx}, master nx is #{master.nx}"	# ERROR: unexpected IDENTIFIER vampire (!) 2014-04-04 21:00

