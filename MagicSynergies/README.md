# Magic Synergies

This mod enhances the immersion of the game by applying various environmental effects to mobile actors (characters or creatures) based on the weather and their surroundings. It introduces a more dynamic system for handling damage from various magic effects in the game.

## Environment Effects

- **Wet Effect:** Characters will appear wet when they are underwater or when it's raining or thundering. This effect is removed when the character is not in these conditions.

- **Charged Effect:** During thunderstorms, characters will appear charged. This effect is removed when the weather is not a thunderstorm.

- **Cold Effect:** In snowy or blizzard conditions, characters will appear cold. This effect is removed when it's not snowing or there's no blizzard.

- **Warm Effect:** During ashstorms or blights, characters will appear warm. This effect is removed when the weather is not an ashstorm or blight.

## Damage Handling

When an actor takes damage from any of the magic effects below additional effects may be triggered. The additional effects are as follows:

- Fire: The actor burns for 5 seconds, taking additional damage over time.
- Frost: The actor is paralyzed for 5 seconds.
- Shock: The actor's fatigue is damaged for 5 seconds.
- Poison: The actor's armor is disintegrated for 5 seconds.

After the additional effect is applied, there is a cooldown period during which the actor cannot be affected by the same magic effect again.

### Fire Damage

Fire damage is affected by whether the actor is wet, cold, or warm. If the actor is wet or cold, the threshold for fire damage is increased, making the actor more resistant to fire. If the actor is warm, the threshold is decreased, making the actor more vulnerable to fire.

### Frost Damage

Frost damage is affected by whether the actor is warm, wet, or cold. If the actor is warm, the threshold for frost damage is increased, making the actor more resistant to frost. If the actor is wet or cold, the threshold is decreased, making the actor more vulnerable to frost.

### Shock Damage

Shock damage is affected by whether the actor is wet or charged. If the actor is either wet or charged, the threshold for shock damage is decreased, making the actor more vulnerable to shock.

### Poison Damage

Poison damage is not affected by any conditions. It has a fixed threshold.
