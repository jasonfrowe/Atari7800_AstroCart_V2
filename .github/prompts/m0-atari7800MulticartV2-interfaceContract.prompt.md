## M0: Interface Contract Freeze for Atari7800 Multicart V2

Purpose: lock all cross-module behavior before HDL implementation starts.

Status: Draft for immediate execution.

## 1. Scope Locked in M0

In scope:
1. Menu-to-loader command semantics at 0x2200.
2. Memory map ownership and conflict rules.
3. Module-level interface contracts and signal responsibilities.
4. ROM validation order and milestone pass criteria for M1 to M3 entry.

Out of scope for initial release:
1. Rich debug register pages beyond LED-only indicators.
2. Save-state and metadata-heavy UI features.
3. FAT write support and nonessential filesystem extras.

## 2. Frozen Command Semantics (Menu Handoff)

Control aperture:
1. Address: 0x2200.
2. Active only in menu/control mode.
3. Writes during game mode are ignored by design.

Command bytes:
1. 0x80 to 0x8F: Load game slot 0 to 15, index = data[3:0].
2. 0x40: Reload command (primary menu shortcut path).
3. 0x5A: Reload alias for backward compatibility with older firmware paths.
4. 0xA5: Menu-side post-ready marker; loader may ignore safely.

Ready/busy status behavior:
1. Status read address: 0x7FF0, menu-mode only.
2. 0x00 means busy/loading.
3. 0x80 means ready/load complete.
4. Games must not depend on 0x7FF0 behavior.

## 3. Memory Map and Ownership Freeze

CPU-visible map:
1. 0x0000 to 0x3FFF: Atari system RAM/IO, not owned by multicart mapper.
2. 0x2200: Menu control write aperture (disabled in game mode).
3. 0x4000 to 0xFFFF: Cart aperture served by menu BRAM or loaded PSRAM image.
4. 0x7FF0: Transitional menu status read (not guaranteed in game mode).

Mapper-specific behavior:
1. Standard mapping:
1. 32KB titles require correct placement behavior for 0x8000 to 0xFFFF execution.
2. 48KB and larger standard titles map across cart aperture per header-derived size.
2. Supercart mapping:
1. 0x8000 to 0xBFFF is switchable bank window.
2. 0xC000 to 0xFFFF is fixed last bank window.
3. Optional RAM-at-4000:
1. If header enables RAM-at-4000, 0x4000 to 0x7FFF is writable cart RAM window.
2. If not enabled, that range remains ROM-served behavior for the active mapper mode.

Pokey decode behavior:
1. Address variants supported from header flags: 0x0450, 0x0440, 0x0800, 0x4000.
2. Decode is per-loaded title configuration.

## 4. Storage and Loader Service Boundary

Architectural split:
1. Softcore plus FAT layer resolves selected filename into a deterministic block-span descriptor.
2. Hardware loader consumes descriptor and performs deterministic SD-to-PSRAM transfer.

Descriptor contract (softcore to loader):
1. start_lba: 32-bit starting block.
2. sector_count: 16-bit number of 512-byte sectors to fetch.
3. payload_skip_bytes: 16-bit skip amount for header alignment handling.
4. target_profile: mapper and addressing profile bits derived from A78 header.
5. pokey_profile: selected Pokey mapping bits.
6. ram_profile: RAM-at-4000 enable bit.

Loader obligations:
1. Transfer blocks exactly once in-order unless explicit retry is requested.
2. Apply CDC-safe handshakes for SD-domain to sys-domain signals.
3. Gate PSRAM writes to avoid runtime ROM corruption after handoff.
4. Assert completion only after final write commit is guaranteed.

Softcore obligations:
1. Resolve FAT path and cluster chains before asserting load request.
2. Provide descriptor with valid bounds and sanity-checked lengths.
3. Keep read-only FAT path first; write operations are deferred.

Fallback mode freeze:
1. Raw-slot mode remains available for regression and recovery.
2. Raw mode descriptor is generated from slot index by fixed formula.

## 5. Timing and CDC Assumptions

Clocking assumptions:
1. System logic domain runs at high-speed system clock.
2. SD transport may run in separate clock domain.
3. Handshake crossings require explicit synchronizers.

CDC hard rules:
1. All SD ready/data-available handshake signals crossing into system domain use two-flop synchronizers minimum.
2. No combinational dependence on asynchronous control levels.
3. Trigger write detection must tolerate pipeline delay between address/control qualification and data validity.

Data integrity rules:
1. Loader completion is not allowed until outstanding PSRAM write is committed.
2. Runtime write protection prevents accidental ROM image corruption after game_loaded state.

## 6. Interface Ownership by Module

Top-level bus arbiter owns:
1. CPU bus decode for ROM, Pokey, and control apertures.
2. Direction control for transceiver behavior.
3. Read-data multiplexing among menu BRAM, PSRAM, and status responses.

Loader/orchestrator owns:
1. Command latch and load state machine lifecycle.
2. Header field extraction and profile outputs.
3. PSRAM write request generation for game payload transfer.

PSRAM controller owns:
1. Device protocol timing and command execution.
2. Busy and data return semantics.

SD transport owns:
1. Card init and block-read primitives.
2. Byte-valid and transaction-ready signaling.

Softcore FAT service owns:
1. File discovery and block-span resolution.
2. Descriptor publication to loader.

## 7. Frozen ROM Validation Order

Execution order:
1. AstroWing 48KB plus Pokey at 0x0450.
2. Choplifter 32KB standard mapping behavior.
3. Commando 128KB supercart plus Pokey at 0x4000 behavior.
4. ARTI supercart plus Pokey at 0x0450 plus RAM-at-4000 path.

Phase entry dependency:
1. M1 to M2 requires AstroWing load-and-boot repeatability.
2. M2 to M3 requires Choplifter mapping correctness.
3. M3 to M4 requires Commando supercart stability.
4. M4 to M5 requires ARTI path functional readiness.

## 8. M0 Exit Checklist

All items must be true:
1. Command semantics at 0x2200 are frozen and documented.
2. Menu-only status-read behavior at 0x7FF0 is frozen.
3. Mapper, Pokey, and RAM-at-4000 ownership rules are frozen.
4. Softcore-to-loader descriptor schema is frozen.
5. ROM validation order is frozen and accepted.
6. No unresolved architectural blockers remain for M1 implementation.

## 9. Immediate Next Actions (Start of M1)

1. Create HDL module stubs matching this contract.
2. Bring up PLL, reset sequencing, and LED state mapping.
3. Validate SD single-block transfer path with synchronized handshakes.
4. Validate PSRAM write/read integrity loop before full loader integration.
