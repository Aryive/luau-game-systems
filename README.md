# luau-game-systems
A few systems from one of my published games, written in Luau.
They're taken from a larger project, so they depend on its data and networking modules and won't run on their own, since its somewhat a modular framework which is really popular in this case a commissioned Roblox Game.

- **GUIController**: menu open/close system with swappable animations, a depth-counted camera zoom for nested menus, and a fallback that repairs stuck UI state
- **OfflineEarningsSystem**: calculates a player's earn rate from their last session and pays out capped offline earnings when they rejoin
- **RebirthSystem**: progression reset that wipes earnable items but keeps purchased ones
- **StateMachine**: small reusable state machine with enter, exit and update hooks
