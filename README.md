# Encore

> **Not released yet.** Encore is still being built and tested on the `dev`
> branch, and isn't on CurseForge or Wago. A first release is coming soon.

A small addon for World of Warcraft: Forever, for enchanters. It does two
things:

- **Skip the replace prompt.** Levelling Enchanting often means putting the
  same enchant on the same item over and over, and every cast stops to ask
  whether to replace the enchant already there. Encore's button casts and
  says Yes in one press.
- **Disenchant from a list.** A window lists everything in your bags you
  could disenchant. Untick what you want to keep, then press once per item.
  Anything that looks worth keeping starts unticked.

## Enchant, skip confirm

Open Enchanting, pick the enchant, and put the item in the window's
enchant slot as usual. An **Enchant, skip confirm** button appears beside
the window's own Enchant button. Each press casts the enchant on the item
and, if the item already has an enchant, says Yes to replacing it.

It's still one press per cast (see below for why). You can put the button
on a key under Options > Keybindings > Encore and tap that instead.

It only answers a replace prompt its own press opened. It never answers
the prompt that asks to make an item soulbound: the first enchant on an
unbound item is yours to confirm.

## Disenchanting from a list

Open it with the **Disenchant All...** button on the Professions window while
Enchanting is open, or type `/encore`. It lists every green, blue and
purple weapon or piece of armour in your bags, with a tick box beside each.

These start unticked, with the reason shown, so nothing you might want
goes by accident:

- gear in one of your equipment sets
- gear you've worn (bind-on-equip items that have become soulbound)
- anything better than what you're wearing in that slot, by item level, or
  by ItemTree's judgement if you have ItemTree
- rare and epic items
- anything on your Goldwise Keep list, if you have Goldwise

You can tick any of them yourself. Anything you untick stays unticked the
next time you open the list.

Then press **Disenchant next** once for each item, or bind a key to it under
Options > Keybindings > Encore. Each press disenchants the next ticked
item, and Encore takes the dust and essences from the loot window so it
never gets in the way. If the game refuses an item (too little skill, say),
it's unticked and the game's reason shows beside it. The list only acts
while it's open.

## Why one press per cast

The game requires a real key press or click for every cast, and an addon
that casts on its own in a loop is what that rule exists to stop. Encore
doesn't try to get around it. What it saves you is the clicking in between:
the prompt after each enchant, or picking each item to disenchant.

Encore also never calls the game's crafting functions itself. The enchant
button presses the Professions window's own Enchant button, and the Yes on
the prompt, through the game's secure button system, so the client casts as
if you'd clicked them. The Disenchant button is a secure button too: the
client casts the spell and points it at the item itself. Crafting called
from addon code is known to block things like potions afterwards on this
client, and this way avoids that.

## Notes

The enchant button only shows up for an enchant on a single item. For a
stack, such as vellum, the window's own Enchant All button already does the
job.

Encore was written with the help of an AI assistant (Claude) and checked
against the game's own interface code.

## Licence

MIT. See [LICENSE](LICENSE).

## More from Flight Path Labs

Small addons for World of Warcraft: Forever, all at
[github.com/flightpathlabs](https://github.com/flightpathlabs).

- [Gold Wise](https://github.com/flightpathlabs/GoldWise): auction prices for what you carry, and what's worth doing with it.
- [Creel](https://github.com/flightpathlabs/Creel): a fishing log and one-key cast.
- [Temper](https://github.com/flightpathlabs/Temper): how your character fights, and whether a change helped. Coming soon.
