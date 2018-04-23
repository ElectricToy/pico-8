THEME: Combine 2 Incompatible Genres

# Genres

FPS
Open World
RPG
JRPG
Hack-n-slash
Dating Simulator
Walking Around Simulator
Tower Defense
Flight Simulator
Physics sim
Puzzle
Point-n-click Adventure
Military strategy
Sports
Town simulator (e.g. Animal Crossing, Betrayed)
Game-Making Game/Editor Game (Mario Maker, Minecraft)
Music Game (Guitar Hero...)
Financial Simulator
Board Game
    Poker
    Chess
    Chutes and Ladders
Space flight simulator (Artemis, Kerbal, Capsule)
Twin-stick shooter (Robotron)
Run-n-gun (Contra, Cuphead)
Text Adventure/Commandline
Elite/Privateer trading game

# Ideas

~~Fighting Dating Sim~~
~~Puzzle RTS (Pikmin?)~~
~~Physics JRPG~~
~~Text Adventure FPS~~
~~Point-and-click Racing~~
~~Turn-based Physics Game~~
~~Open World Text Adventure~~
~~Open World Racing~~
~~Open World Point-n-click~~
~~Open World Sports~~
~~Walking Around Sports~~
~~Walking Around Military Strategy~~
~~Roguelike Dating Simulator~~
~~Roguelike Physics Sim~~
~~Roguelike Flight Simulator~~
~~Music Physics Game~~
~~Roguelike Music Game~~
~~RTS Music Game~~
~~Twin-stick Music Game~~

Fighting
Turn-based
Music Game
Racing
RTS

Roguelike
Platformer
Survival
Stealth
Twin-stick shooter
Shoot-em-up
Bullet Hell
Commandline

Survival Platformer
Stealth Roguelike
Platformer RTS (Killer Queen)
Stealth Tower Defense/RTS

# Genre Combo Criteria

1. Accomplishable
1. Fun
1. High Contrast
1. Funny
1. Mechanically Contrasting

# Game Goals

1. Accomplishable
1. Simple
1. Familiar/minimal teaching
1. Fun
1. Funny
1. Big Personality/Characters
1. Short



# EXPLORE: Survival Platformer

Avoiding death as long as possible due to cold, hunger, sickness, or predation.
Fight these things through:
    * collecting/gathering - exploration
    * crafting?
    * sleep

# EXPLORE: Endless Runner Survival

Avoiding death as long as possible due to cold, hunger, sickness, or predation.

Fight these things through:
    * collecting/gathering
    * crafting
    * sleeping
    * eating
    * staying near warmth/keeping source of warmth (clothing?)
    * retain source of light
    * avoiding predators (dodge?)

Controls:

- jump
- pickup
- arrow keys to craft

Modal: jump vs craft (quiet phases; uphill/downhill?)

DANGERS:

- Collision
    + Jumping
- Enemies
    + Jumping (some enemies)
    + Health
    + Weapons
    + Armor
    + Distractions (bait)
- Hunger
    + Food
- Darkness
    + Light sources (day)

## UI Elements

Crafting interface
Inventory (owned stuff)
Status
    Health
    Hunger
(Light represented in-world)
(Speed represented in-world)
Danger/warning flashes and messages

? Weapon control
? Weapon+Armor too much without cold?
? Too thin without fourth thing
? Sickness
? Cold

## Creature Pattern

0:00    Creature text warning
0:05    Creature at edge of screen
    ~ Random variance ~
0:10    Creature flash
    ~ Delay based on difficulty ~
    0:10.5 IF WEAPON: Kill creature
0:11    Creature attack motion and strike point
    FOR SOME CREATURES: Chance to return to 0:05
0:12    Drops away

Flash only if you _should_ jump.

## Creature Types

Rat
Bat
Condor
Snake
Wolf

## Pickups 

Coin
Pre-crafted things
Ingredients

# End-of-Game

Distance
Coins

# Schedule

## Vertical Slice - Tonight

X Box character
X Jump button
X Things to jump over
X Something to pick up (coin?)
X Pickup button
X Platforms
X Creature
X Environment with motion
X Craft one item with blank rest of crafting tree
X Owned item inventory
    X Used/Need hints
- Light/dark
- difficulty ramp
- title screen
X Jump hint
~~- Grab button hint~~
~~- jump hint (with monster)~~

## Expansion - Saturday

X Player character with all animations
X Environment art
X UI details (e.g. crafting requirements, warning signs)
X Items
X Creatures

## Polish - Sunday

X background with dithered gradient
X Music
X SFX
- Tuning
- Extra art variations


## FINAL POLISH

X Apples (Jeff)
X Bananas (Jeff)
X Small rock (Liam/Jeff)
X Mushroom art
X hunger flash when nearly dead (and health etc)
~~- Day/night cycle with darkness, torch (Jeff)~~
~~- Snake (Jeff/Liam??)~~
- Item distribution (Liam): look for 'shoulddrop = function(level)'
    + craft balancing (Liam): look for 'requirements'
    + item power (Liam): look for 'oncreated'
- fast/slow
- Title screen (Jeff)
- Fast/slow run periods (Jeff)
- Difficulty ramp (Jeff)
    + 1 jump quest: no creatures, rocks only, until jump
    + 2 torch quest: no creatures, small rocks only, specific items for torch, done when create torch, then sunset immediately
    + 3 first night: add arbitrary items, more stones; done with time
    + 4, 5 second day: fox
    + 6, 7 third day:  frog
    + 8, 9 fourth day: snake
    + PERPETUAL DIFFICULTY RAMP
    + Subsequent plays start on second day
- performance problem when you craft something
- frog initial y position
- spend all arrows with weapon

# Draw Tech

Background fill
Background tiling (e.g. mountains, clouds)
Background sprites (e.g. trees, near hills)
Ground tiles with platforms
Actor sprites

# Items

Auto Items (Get used the moment you pick them up)
	• Apple = Instantly heals one heart - uncommon
	• Banana = Instantly heals one half hunger - uncommon

Craftable Items
	• Raw Meat - rare pickup, obtained from enemies when shot
	• Mushroom - uncommon pickup
	• Wheat - rare pickup
	• Stick - MOST common pickup
	• Oil - uncommon pickup
	• Metal - rare pickup

Tools
	• Bow = 4 Stick + 2 Metal
		You must craft a bow in order to use arrows. One bow can shoot 5 arrows before breaking.
	• Arrow = 1 Metal + 1 Stick
		If you have one, you will automatically kill enemies.
	• Armor = 3 Metal + 2 Oil
		Makes every attack do one half heart damage.

Food
	• Cooked Meat = 1 Raw Meat + 1 Torch (torch doesn’t get consumed)
		Heals one full heart and 3 full hungers.
	• Stew = 5 Mushroom + 3 Raw Meat
		Adds one full hunger to max, heals all hunger.
	• Pizza = 3 Wheat + 3 Mushroom + 3 Raw Meat
		Adds one full heart to max, heals three hearts.

Other
	• Torch = 1 Oil + 2 Stick
		Allows you to see better at night. One torch lasts one night.







Game names

Octane Survival / High Octane Survival / Hi-Octane Survival
Life on the Run
Survival on the Run
Crafting on the Run
Turbocraft / Nitrocraft
Running from Convention
Haste makes waste
Run from the sun
Run from the night
Survival Marathon
MarathonCraft
Sonicraft
Survival Run 







