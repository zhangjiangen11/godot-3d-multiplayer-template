# Documentation

## Available Documentation

### [Inventory System](inventory-system.md)
Comprehensive guide to the server-authoritative multiplayer inventory system, including:
- Architecture overview and client-server interactions
- RPC methods and data flow diagrams  
- Server validation
- Usage examples and troubleshooting
- Performance considerations

## Quick Reference

### Key Controls
- `B` - Toggle inventory
- `F1` - Add random test item (debug)  
- `F2` - Print inventory contents (debug)

### Main Components
- **Server Authority**: All inventory operations validated server-side
- **Client Privacy**: Each player's inventory only syncs with server and owner
- **Real-time UI**: Immediate updates for drag-and-drop and item operations
- **20-Slot Grid**: Organized inventory with item stacking support

### Network Flow
```
Client Request → Server Validation → Server Processing → Client Update → UI Refresh
```

For detailed technical information, see the individual documentation files.