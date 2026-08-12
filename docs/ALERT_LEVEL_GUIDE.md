# P4 EA Alert Level Configuration Guide

## Overview

The P4 EAs (both main and XAUUSD Pullback versions) now support alert level filtering to reduce notification spam while keeping critical information.

## Alert Level Parameter

Both EA files include a new input parameter:

```mql5
input int AlertLevel = 1;  // Alert level: 0=none, 1=important only, 2=all
```

### Alert Level Options

#### Level 0: No Alerts
- **All alerts are disabled**
- Best for: Fully autonomous trading without notifications
- Use case: Live trading where you don't want any popups

#### Level 1: Important Only (DEFAULT - RECOMMENDED)
- **Shows only critical trading decisions and warnings**
- Alerts shown:
  - ✓ Entry signals (LONG/SHORT ENTRY SIGNAL)
  - ✓ Critical trade management (TP reached, SL moved to breakeven)
  - ✓ BB breakout detected (TP extended)
  - ✓ Warnings about trend reversals (EMA80 breakout)
  - ✓ Trade closure reasons
  - ✗ Skip messages (25% skip rule, no Perfect Order, news time)
  - ✗ Informational messages (BB overshoot details, N-shape patterns)
  - ✗ EMA divergence skip reasons

#### Level 2: All Alerts
- **Shows every alert including informational messages**
- Use case: Detailed monitoring and debugging
- Alerts shown: Everything from Level 1 plus:
  - ✓ Skip messages (why trades were rejected)
  - ✓ BB overshoot information
  - ✓ N-shape pattern detection messages
  - ✓ EMA divergence warnings

## Alert Classification

### Level 1 (Important) Alerts

**Entry Signals:**
```
LONG ENTRY SIGNAL on EURUSD
SHORT ENTRY SIGNAL on EURUSD
SHORT Entry Signal: Upper Wick Rejection at 4175.67
```

**Trade Management:**
```
LONG: Initial TP reached. SL moved to breakeven.
SHORT: Initial TP reached. SL moved to breakeven.
LONG: BB breakout detected. TP extended to level 2.
SHORT: BB breakout detected. TP extended to level 2.
```

**Warnings:**
```
WARNING: Price broke above 1H EMA80 - Potential trend reversal!
Trade closed: Perfect Order reversal
Trade closed: EMA80 TP reached
```

### Level 2 (Informational) Alerts

**Skip Reasons:**
```
SHORT signal SKIPPED (25% skip rule) on EURUSD
4H PO not in SHORT position - Skipping
Skipping trade - Economic news time
```

**Detailed Conditions:**
```
SHORT: BB Overshoot detected! Using reduced RR 0.75 on EURUSD
EMA divergence too high - Skipping entry at 4175.67
LONG: N-shape detected. Extending profit beyond EMA80.
SHORT: N-shape detected. Extending profit beyond EMA80.
```

## How to Change Alert Level

### Method 1: In MT5 Terminal
1. Open the EA properties (double-click the EA in the chart)
2. Find the "Inputs" tab
3. Change `AlertLevel` parameter:
   - 0 = No alerts
   - 1 = Important only (default)
   - 2 = All alerts
4. Click OK to apply

### Method 2: Edit the EA Code
Open the MQL5 file and change:
```mql5
input int AlertLevel = 1;  // Change 1 to 0 or 2
```

## Recommendations

### For Live Trading (Real Money)
- **Use Level 1 (default)**
- You'll be notified of entries, exits, and warnings
- Skip messages won't spam your alerts
- Keeps you informed without too much noise

### For Paper Trading / Testing
- **Use Level 2**
- See everything that's happening
- Understand why trades were skipped
- Debug strategy behavior

### For Fully Automated / Hands-Off
- **Use Level 0**
- No alerts at all
- EA runs silently
- Check trade log in MT5 later

## Alert Throttling

All EAs include alert throttling to prevent duplicate alerts within 5 minutes (300 seconds). Even with Level 2, you won't see the same message repeated back-to-back.

## Print Logging

**Note:** All alerts are also printed to the "Experts" tab in MT5, regardless of AlertLevel setting. This provides a complete record of EA activity for review.

To view the logs:
1. Open MT5 Terminal
2. Go to "Experts" tab
3. Search for your symbol and EA name

## Files Modified

- `mql5/Experts/P4_Signal_EA.mq5` - Main EA with alert level filtering
- `mql5/Experts/P4_Signal_EA_XAUUSD_Pullback.mq5` - Gold-specific EA with alert level filtering

## Summary Table

| Alert Type | Level 1 | Level 2 |
|---|:---:|:---:|
| Entry Signals | ✓ | ✓ |
| Trade Management | ✓ | ✓ |
| Warnings | ✓ | ✓ |
| Skip Messages | ✗ | ✓ |
| Info Messages | ✗ | ✓ |
| Print Log | ✓ | ✓ |

---

**Version**: 1.0  
**Updated**: 2024
