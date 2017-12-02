LD40
====

Theme: "The more you have, the worse it is."

Sigh. Lame theme. Not sure I'll bother with it.

Just watched the keynote and it kicked up my inspiration somewhat.

Right.

# Brainstorm

## "What is *it*?"

* pollution
* tower of blocks
* ugliness
* friends
* enemies
* holes
* poison
* money
* power (corrupts absolutely)
* evil
* alcohol
* sludge
* fire
* zombies
* disease

## Mechanisms

* start with lots, get rid of it
* it's useful, but accumulates in a bad way
* each level you have more of it, and that makes the level harder (but it's reasonably static in the level)
* start with little or none, it accumulates, you have to get rid of it.

9:18 PM

## Technologies

* Pixel sand
* top-down/orthographic
* side view
* large format

# Observations

The "have" word militates against things like "enemies" or maybe even "disease." I like the contrast implied by "having" in the sense of owning and retaining a thing, but the thing is problematic, especially as it gets "more" (more volume/mass/amount). So this implies two general thematic emphases: either you "have" it in the sense that it's an attribute (like ugliness or beauty) that simply accrues to you and you have to manage and/or divest it, or it's a commodity (like ammo or, perhaps, fire) that is basically desirable and positive but has a serious downside at mass. Yes, I think I need this contrast: "it" is neither wholly positive or negative; the volume determines that. This implies a fundamental gameplay choice, balancing one's ownership of The Thing. Secondary is the question of whether the thing is an intrinsic attribute (like ugliness) or an extrinsic commodity (like ammo or wealth). This implies a pretty strong economy that is interesting.

I'm attracted to doing a sand-type technology but we'll see. That's secondary.

9:26 PM

So, some quick winners: money, fire. Freedom is an interesting one, as in degrees of freedom but with a parabolic significance. Friendship is interesting, albeit a little cynical or antisocial.

Let's explore this freedom concept a moment. This would be a puzzle game in which controlling your degrees of freedom is a positive action. The key idea would be that although freedom seems good at first, it's only when you contain the degrees of freedom that you are able to resolve the problem. How would you structure such a puzzle? Immediate confusion results from the reality that puzzle *design* always has this property: to make a hard puzzle, make it highly floppy, yet requiring a precise solution; to make an easy one, make only a few paths through the puzzle, and allow many solutions. That's what the designer thinks about. But how to make a game that allows the gamer to control that? A physics game could do it; the challenge might be to stack up objects to reach some high point. Everything's jointed, but you can spend X to restrict the joints. Hm.

Money would seem to be the most promising one. This would be a financial simulation of some kind, where greater wealth would seem to be beneficial but actually exposes the player to greater risk (tax, fraud, cheating, spoiled friendships, worry, shallowness...?). It's not quite true that the correlation is linear: there's some minimum amount below which things get "worse" too. Reigns comes to mind as a vaguely similar paradigm. I'm thinking too of my "life finances" game concept.

Let's move deeper with this. It really is promising. It feels pico-8-ish. I'm motivated at a broader level (i.e. I've been looking for a chance to code this).

It's essentially a board game, in essence. Real-time simulation is a non-issue. Physical coherency is a non-issue. Instead you basically are dealing in "tokens" of various kinds.

Okay, I'm moving to paper.

9:37 PM Saturday Dec 1

# Financial Game: Goals

1. Educate about personal finances. (Snore. But I really am motivated.)
1. Be fun and motivating.
1. Simulate personal/relational/moral/meaningful ramifications of financial choices.
1. Remain reasonably realistic and plausible.
1. Narrow enough to be learnable and manageable (and implementable!).
1. Broad enough to explore a fairly full simulation.

# Assumptions

* Single player
* 5-10 minutes basic gameplay

# Mechanisms

Each turn is a year.
Events inject human and story effects (much like Democracy).

# Events

* Divorce due to strain
* Market downturn
* Fraud
* Embezzlement
* Theft, burglary, robbery
* Bad health
* Accident (car, etc.)
* Burned house/tornado/flood
* Bad advice
* Spoiled kids
* Splurge
* Heart attack due to stress
* Foreclosure
* Bankruptcy
* Identity theft
* Kids go to college
* Kids get married

# Commodities

* Money
* Joy
* Relational health (i.e. happiness of people near you)
* Stress
* Status
* Credit

# Choices

* Marriage
* Purchases
* Investments
* Vacation (-stress)

# Structure

* Absolutely turn-based.
* Game goes from age 20 to age X (normally 80), each turn simulating Y years (1? 2? 5?).
* On a turn
    - Receive events, some of which offer choices.
    - View status (accounts, health, joy, relatives...)
    - Make choices (investment, etc.)
* Game over when you die. Score is _joy_ only.

Reign essentially makes events=choices and vastly simplifies status. I can't simplify status that much but I *can* conflate events and choices if I like. This would simplify and streamline the game a lot at the expense of realism. Essential the player is purely reactive in making choices. "An investment is available. Take it?"

I think that's too simple. I can certainly push choices into reactive events wherever possible, and that's meritorious, but the "life simulation" goal requires an active, choice-grabbing aspect. This makes it more like Democracy.

# UI

Basically a general status screen overlaid (more or less) by (1) events, (2) purchase interfaces, (3) detailed status, charts, etc.

# General Reflections

I'm confident in this. The only question is the size of the UI and how hard it will be to implement. NOW for the paper...

9:56 PM

# Structure of Concerns

* Joy
* Wealth
* Personal attributes: stress, health, credit rating, job info
* Relationships (Person A, Person B...)
* Accounts
* Possessions

# Classes

Effect
    effect_amount
    mode ("momentary", "stateful", "perennial")

Thing
    name
    age
    joy effect
    joy effect curve
    wealth effect
    wealth effect curve
    health effect
    health effect curve
    status effect
    status effect curve

Person : Thing
    name
    joy
    wealth
    health
    status
    demanded status ("ambition")

Player : Person
    education
    job
    status
    spouse
    children
    credit rating
    wealth
    accounts
    possessions

Job
    cost (i.e. education cost)
    wealth effect (i.e. salary)
    mobility (raise range curve)
    status effect

CollegeStudent : Job
    education_term
    resulting_job
    resulting_reemployment_chance_range

Unemployed : Job

Account
    initial balance
    credits and debits
    balance history (for graphs)
    current balance

Loan : Account
Investment : Account

Possession
    cost
    value
    status effect
    joy effect
    (event triggers)

Event
    name
    description
    condition_chances
    effects (fn)
    is_choice

10:15 PM DMV

10:20 PM

Shoot, I just remembered that pico-8 has no mouse control to speak of. Not the end of the world, but it certainly shapes the nature of the UI.

# UI Design

## Game Main Area

* General quick status area (joy, wealth, health, status).
* Family -> Detail views per person
* Accounts -> Account list -> Detail views per account
* Possessions -> Possession callout/sell interface
* Help text bar

## Event

## Setup

Play -> Difficulty, name, etc. -> Game

## Game Results