# Encore

A small addon for World of Warcraft: Forever, for enchanters who level the
profession by putting the same enchant on the same item over and over.

Normally each cast is three clicks: the enchant, the item, then Yes on the
"replace the existing enchant?" prompt. With Encore it's one press per cast,
and it keeps count.

## How to use it

1. Open Enchanting, pick the enchant, and put the item in the window's
   enchant slot as usual.
2. A **Repeat** button appears beside the window's Enchant button, with a
   box for how many casts you want (10 to start with).
3. Press **Repeat** once for each cast. Each press casts the enchant on that
   item and, when the item already has an enchant, says Yes to replacing it.
   Beside the button you'll see how many are left, such as "7 of 10 left".

The run ends by itself when the count is done, when you run out of
materials, or when the enchant stops giving skill (it turns grey, or
Enchanting reaches the cap for your rank). A short note beside the button
says which. Right-click the button, or type `/encore stop`, to end a run
early. Picking another enchant or item ends it too.

You can put the button on a key under Options > Keybindings > Encore, and
then press that key once per cast without moving the mouse.

## Why one press per cast

The game requires a real key press or click for every cast, and an addon
that casts on its own in a loop is what that rule exists to stop. Encore
doesn't try to get around it. What it saves you is the moving between the
enchant, the item and the prompt.

Encore also never calls the game's crafting functions itself. Its button
presses the Professions window's own Enchant button, and the Yes on the
prompt, through the game's secure button system, so the client casts as if
you'd clicked them. Crafting called from addon code is known to block
things like potions afterwards on this client, and this way avoids that.

It only answers a replace prompt that its own press opened. It never
answers the prompt that asks to make an item soulbound: the first enchant
on an unbound item is yours to confirm.

## Settings

Options > AddOns > Encore, or `/encore`:

- **Answer the replace prompt** (on): the same press says Yes. Turn it off
  and the next press says Yes instead.
- **Stop when the skill-ups stop** (on): turn it off to keep going after the
  enchant turns grey.

## Notes

Encore only shows up for an enchant on a single item. For a stack, such as
vellum, the window's own Enchant All button already does the job.

Encore was written with the help of an AI assistant (Claude) and checked
against the game's own interface code.

## Licence

MIT. See [LICENSE](LICENSE).
