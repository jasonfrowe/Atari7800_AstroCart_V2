## M3 Focused Validation Checklist: Commando and ARTI

Goal: isolate mapper vs Pokey audio vs RAM-at-4000 issues quickly with minimal ambiguity.

## 1. Test Scope

1. ROM A: Commando (128KB Supercart, Pokey at 0x4000).
2. ROM B: ARTI (Supercart, Pokey at 0x0450, 16KB RAM at 0x4000).
3. Baseline already known-good: AstroWing and Choplifter.

## 2. Preflight (Do Before Each Session)

1. Rebuild and program latest bitstream.
2. Confirm menu renders and cursor moves normally.
3. Confirm SD media is the expected image and game order has not changed.
4. Capture initial LED state in menu idle.
5. Keep a short run log with timestamp, selected game index, LED transitions, and observed behavior.

## 3. Commando Validation (Mapper + Pokey@4000)

### 3.1 Entry Criteria

1. Menu stable for at least 30 seconds idle.
2. AstroWing can still boot in the same programmed session.

### 3.2 Steps

1. Select Commando once and wait for load transition.
2. Observe immediate post-load behavior: black screen, reset loop, title screen, or gameplay.
3. If booted, let attract/demo run at least 60 seconds.
4. Start gameplay and force frequent scene changes for 2 to 3 minutes.
5. Return to menu flow if available, then re-select Commando.
6. Repeat load-and-run cycle 5 times.

### 3.3 Exactly What To Observe

1. Mapper symptoms:
1. Wrong or scrambled graphics after boot.
2. Crash after first scene transition.
3. Repeating code path or stuck attract loop.
4. Audio symptoms (Pokey at 0x4000):
1. No audio at all with otherwise valid gameplay.
2. Consistent static/noise replacing expected effects.
3. Audio present only in menu or only in limited scenes.
5. Timing/transfer symptoms:
1. Random boot success rate across retries.
2. Longer-than-usual load followed by immediate lockup.
3. Different failure mode on each run.

### 3.4 Pass Criteria

1. Boots successfully in at least 5 out of 5 attempts.
2. No graphics corruption across scene changes.
3. Audio effects remain consistent and correct in gameplay.

### 3.5 Fast Fault Isolation (Commando)

1. Boots with correct visuals but no audio: likely Pokey decode/mapping issue at 0x4000.
2. Boots then crashes on transition: likely bank-switch write/decode issue.
3. Inconsistent success run-to-run: likely SD-to-PSRAM transfer/handshake reliability issue.

## 4. ARTI Validation (Supercart + Pokey@0450 + RAM@4000)

### 4.1 Entry Criteria

1. Commando has at least one successful clean run in same session.
2. No abnormal LED stuck states after previous run.

### 4.2 Steps

1. Select ARTI and wait for transition.
2. Observe startup behavior through title to first interactive scene.
3. Exercise gameplay paths that force state updates likely to use cart RAM.
4. Run for at least 3 minutes, including transitions and repeated action loops.
5. Soft-reset or return flow, then reload ARTI.
6. Repeat at least 5 runs.

### 4.3 Exactly What To Observe

1. Mapper symptoms:
1. Wrong code/data fetch behavior after transition points.
2. Deterministic crash at the same scene boundary.
3. RAM-at-4000 symptoms:
1. Gameplay state fails to persist between frames/actions.
2. Logic corruption without full CPU crash.
3. Reproducible faults when in-game state grows.
4. Audio symptoms (Pokey at 0x0450):
1. Missing or distorted effects while graphics stay stable.
2. Audio changes tied to specific game states only.

### 4.4 Pass Criteria

1. Boots and enters gameplay in at least 5 out of 5 attempts.
2. No deterministic crash at known transition points.
3. No evidence of state corruption attributable to RAM-at-4000 path.
4. Audio behavior remains correct and stable.

### 4.5 Fast Fault Isolation (ARTI)

1. Good boot plus bad state progression: likely RAM-at-4000 arbitration/write-enable issue.
2. Good visuals plus bad audio only: likely Pokey 0x0450 decode path.
3. Early crash at same boundary: likely supercart bank mapping issue.
4. Non-deterministic failures: likely transfer/timing integrity issue rather than pure mapper logic.

## 5. LED Observation Matrix (Use During Both Tests)

1. Record LED state at three points:
1. Before select in menu.
2. During load transition.
3. In stable gameplay.
2. Flag as suspicious:
1. Load indicator never toggles during selection.
2. State indicator does not change between menu and game mode.
3. Heartbeat stops or freezes during failure.

## 6. Regression Guardrails

1. After any Commando or ARTI failure, immediately retest AstroWing.
2. If AstroWing now fails in same session, classify as global path regression.
3. If AstroWing remains stable, classify as mapper/profile-specific defect.

## 7. Exit Gate for M3

All must be true:
1. Commando passes 5 of 5 clean runs with stable audio.
2. ARTI passes 5 of 5 clean runs without RAM-at-4000 corruption signs.
3. No regression in AstroWing and Choplifter after stress runs.
4. Failure log (if any) includes exact trigger point and LED timeline.

## 8. Quick Log Template

1. Build hash/bitstream timestamp:
2. SD image date/order:
3. Test ROM:
4. Attempt number:
5. LEDs pre-select:
6. LEDs during load:
7. LEDs in game:
8. Boot result:
9. Visual result:
10. Audio result:
11. State persistence result:
12. Failure boundary (if any):
13. Notes:
