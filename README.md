# Chess++ 

A chess game built in Godot 4.6 with a twist - card-based gameplay modifiers!

## Current Status

✅ **Implemented:**
- Complete chess board with all pieces
- Custom chess piece graphics (white and black sets)
- Full chess rules implementation:
  - All piece movements (Pawn, Rook, Knight, Bishop, Queen, King)
  - Capture mechanics
  - Turn-based gameplay
  - Check detection
  - Checkmate detection
  - Pawn promotion (automatic to Queen)
  - Move validation (prevents moving into check)
- Visual board with highlighted possible moves
- Click-to-select and click-to-move interface
- Larger window (1200x1000) and board size (120px squares)
- **Card System:**
  - Separate decks for each player
  - Hand display with card UI
  - Card drawing at start of turn
  - Card targeting system
  - One card per turn limit
  - 8 starter cards with different effects
  - Piece modifier system

## 🎴 Available Cards

1. **Forward Strike** - Target pawn can capture forward for 1 turn
2. **Knight's Leap** - Target piece can also move like a knight this turn
3. **Freeze** - Target enemy piece cannot move next turn
4. **Shield** - Target piece cannot be captured for 1 turn (not yet fully implemented)
5. **Double Time** - Move target piece twice this turn
6. **Swap** - Exchange positions of two friendly pieces (not yet fully implemented)
7. **Long Range** - Target piece can move 2 extra squares this turn (not yet fully implemented)
8. **Tactical Retreat** - Target piece can move backwards this turn (not yet fully implemented)

## How to Play

1. Open the project in Godot 4.6 or later
2. Run the project (F5)
3. **Turn Flow:**
   - Draw a card automatically at start of turn
   - (Optional) Click a card in your hand at the bottom to play it
   - If card needs a target, click on a piece (yours or enemy's depending on card)
   - Select a piece and make your chess move
   - Turn ends automatically
4. Click on a piece to select it (shows green highlights for valid moves)
5. Click on a highlighted square to move the piece
6. Watch for the yellow glow on pieces with active card effects!

### 🎴 How Card Effects Work:

- **Forward Strike** on a Pawn - Click the card, click your pawn, then move it and it can now capture forward!
- **Knight's Leap** on any piece - Click card, click piece, then see it can jump like a knight!
- **Freeze** on enemy - Click card, click enemy piece, they can't move next turn!
- **Double Time** - Click card, click piece, move it, then move it again!

Effects last for the duration shown on the card. Pieces with active effects glow yellow.

## Project Structure

```
Chess-/
├── assets/
│   ├── pawn.png, rook.png, knight.png, bishop.png, queen.png, king.png (black pieces)
│   └── pawn-3.png, rook-3.png, knight-3.png, bishop-3.png, queen-3.png, king-3.png (white pieces)
├── scenes/
│   ├── main.tscn           # Main game scene
│   ├── chess_board.tscn    # Chess board scene
│   ├── chess_piece.tscn    # Individual piece scene
│   ├── card_ui.tscn        # Card display component
│   └── hand_display.tscn   # Player's hand container
├── scripts/
│   ├── main.gd             # Main game controller with card logic
│   ├── chess_board.gd      # Board logic and game rules
│   ├── chess_piece.gd      # Piece behavior and movement
│   ├── card.gd             # Card data structure
│   ├── card_library.gd     # All available cards
│   ├── deck.gd             # Deck management
│   ├── piece_modifier.gd   # Card effects on pieces
│   ├── card_ui.gd          # Card UI display
│   └── hand_display.gd     # Hand container logic
└── project.godot
```

## Asset Format

The game expects PNG images in the `assets/` folder:
- **Black pieces**: `pawn.png`, `rook.png`, `knight.png`, `bishop.png`, `queen.png`, `king.png`
- **White pieces**: `pawn-3.png`, `rook-3.png`, `knight-3.png`, `bishop-3.png`, `queen-3.png`, `king-3.png`

Pieces are automatically scaled to fit 100px target size.

## Card System Architecture

### Card Types
- **Instant**: Plays immediately
- **Piece Modifier**: Temporarily modifies a piece's abilities
- **Board Effect**: Affects the board/game state

### Targeting
- **No Target**: Card plays instantly
- **Own Piece**: Must select your piece
- **Enemy Piece**: Must select opponent's piece
- **Any Piece**: Can select any piece

### Modifier Duration
- **0**: Instant effect (used immediately)
- **1+**: Number of turns the effect lasts

### Effect System
Cards apply `PieceModifier` objects to pieces, which modify their `get_possible_moves()` method to add/restrict movement options.

## Development Notes

- Built with Godot 4.6
- Uses GDScript
- 2D chess implementation
- Board: 8x8 grid with 120px squares (960px total)
- Window: 1200x1000 pixels
- Each player has their own 24-card deck (3 copies of each card)
- Cards are drawn from deck, played to discard, reshuffled when empty

## Next Steps

### Immediate Improvements
1. Finish implementing remaining card effects (Shield, Swap, Long Range, Backstep)
2. Add visual indicators for active modifiers on pieces
3. Better card artwork/icons
4. Animation for card playing
5. Sound effects

### Future Features
- Castling and En passant chess rules
- Player choice for pawn promotion
- Deck customization/building
- Deck upgrades system
- More cards with unique effects
- Tournament/campaign mode
- Online multiplayer
- Card rarity system
- Card pack opening

