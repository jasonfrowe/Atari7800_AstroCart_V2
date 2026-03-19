## Plan: Atari7800 V2 Clean-Restart Bring-Up

Build a stable V2 multicart baseline on Tang 9K by reusing proven low-level blocks first, then rebuilding timing-critical orchestration around your new PCB assumptions. Since you selected softcore + FAT as direction, the plan uses a two-lane strategy: first establish a known-good hardware datapath with deterministic loading, then integrate a softcore file layer after core reliability is proven.

**Current execution status**
1. M0 started.
1. M0 contract artifact created: .github/prompts/m0-atari7800MulticartV2-interfaceContract.prompt.md.
1. M1 started.
1. M1 foundation HDL added: top.v, sd_controller.v, psram_controller.v, gowin_pll.v.
1. M1 synthesis smoke test passed and generated Atari7800_AstroCart.fs.
1. M2 integration started: proven loader/handoff modules ported from previous project baseline.
1. M2 integration build passed and generated Atari7800_AstroCart.fs for board validation.
1. Hardware validation: AstroWing boots and runs from menu selection.
1. Hardware validation: Choplifter selection loads quickly and game runs.

**Phase-By-Phase Execution Checklist (Entry/Exit Gates)**

1. Milestone M0 - Requirements and Interface Freeze
1. Entry criteria:
1. SD strategy is fixed to softcore + FAT.
1. First success target is fixed to AstroWing from SD to PSRAM with Pokey.
1. Debug scope is fixed to LED-only.
1. Execution checklist:
1. Define signal-level contracts for bus arbiter, loader, SD service boundary, PSRAM write/read path, mapper select, and Pokey decode.
1. Freeze menu trigger semantics and accepted command bytes.
1. Freeze memory-map decisions for ROM, mapper registers, and RAM-at-4000 behavior.
1. Record explicit out-of-scope items for initial release.
1. Exit criteria:
1. One written interface contract exists and is accepted.
1. No unresolved architectural blockers remain for hardware implementation.
1. A ROM test order is locked: AstroWing, Choplifter, Commando, ARTI.

1. Milestone M1 - Foundation Bring-Up (Clock, PSRAM, SD Block Path)
1. Entry criteria:
1. M0 accepted.
1. Constraint and build flow are runnable.
1. Board powers and programs reliably.
1. Execution checklist:
1. Integrate and validate PLL clocks and reset sequencing.
1. Validate PSRAM init and deterministic read/write transactions.
1. Validate SD card initialization and single-block reads.
1. Enforce CDC synchronization on SD status/data handshakes crossing clock domains.
1. Confirm no legacy bad-PCB delay hacks are present in new timing paths.
1. Exit criteria:
1. Deterministic SD block read succeeds repeatedly without partial transfers.
1. PSRAM readback matches written payload across repeated trials.
1. LED states clearly show init complete and fault conditions.

1. Milestone M2 - Loader and Menu Handoff (Raw Deterministic Path)
1. Entry criteria:
1. M1 accepted.
1. Menu build artifact generation is stable.
1. Game index trigger write path is defined end-to-end.
1. Execution checklist:
1. Implement loader state machine to consume block spans and write PSRAM.
1. Parse A78 header fields required for size, mapper, Pokey address, and RAM-at-4000.
1. Apply write-gating so in-game writes cannot corrupt loaded ROM image.
1. Implement clean handoff from menu mode to game mode after load complete.
1. Keep a raw slot fallback mode enabled for regression and recovery.
1. Exit criteria:
1. AstroWing loads from SD to PSRAM and boots from menu handoff.
1. Pokey audio is audibly correct for AstroWing.
1. Ten consecutive load-and-boot cycles succeed with no silent truncation.

1. Milestone M3 - Mapping Correctness (32KB and Supercart Paths)
1. Entry criteria:
1. M2 accepted.
1. Header-derived mapper configuration is active.
1. Execution checklist:
1. Implement and verify 32KB mapping behavior required by Choplifter.
1. Implement and verify supercart banking path used by larger titles.
1. Verify per-game Pokey address decode variants including 4000 and 0450 cases.
1. Implement RAM-at-4000 arbitration and write-enable behavior without ROM conflicts.
1. Exit criteria:
1. Choplifter boots and runs with stable graphics and controls.
1. Commando boots and runs with correct banking and Pokey behavior.
1. No mapper regressions observed when returning to AstroWing baseline.

1. Milestone M4 - Softcore + FAT Service Integration
1. Entry criteria:
1. M3 accepted.
1. Resource budget for selected softcore fits timing and utilization margin.
1. Storage service API between softcore and hardware loader is frozen.
1. Execution checklist:
1. Bring up softcore boot path and firmware image loading.
1. Implement read-only FAT file resolution to block spans.
1. Feed resolved block spans into the existing deterministic loader pipeline.
1. Retain raw-slot fallback path for A/B comparison and field recovery.
1. Handle expected FAT happy path first, then fragmented-file edge cases.
1. Exit criteria:
1. AstroWing can be loaded by FAT-selected file path and boot successfully.
1. Raw fallback mode still functions unchanged.
1. Timing closure and device utilization remain within acceptable margin.

1. Milestone M5 - End-Game Validation and Reliability Sign-Off
1. Entry criteria:
1. M4 accepted.
1. Full ROM set is available on prepared media.
1. Test logging method for pass/fail and failure signatures is defined.
1. Execution checklist:
1. Run full staged validation: AstroWing, Choplifter, Commando, ARTI.
1. Stress repeated load cycles and warm-reset transitions.
1. Record and triage any timeout, mapper mismatch, or audio anomalies.
1. Confirm ARTI path: supercart behavior, Pokey mapping, and RAM-at-4000 integration.
1. Exit criteria:
1. ARTI boots and runs through target gameplay checks without mapper faults.
1. Repeated load-cycle sweep completes with no intermittent load failures.
1. Release checklist is complete and build/program flow is reproducible.

1. Milestone M6 - Tooling, Documentation, and Handoff
1. Entry criteria:
1. M5 accepted.
1. Build and programming scripts execute end-to-end on current environment.
1. Execution checklist:
1. Finalize reproducible build sequence for menu, synth, and programming.
1. Document SD preparation flow for FAT and fallback regression mode.
1. Publish concise bring-up and troubleshooting checklist tied to LED diagnostics.
1. Exit criteria:
1. A clean-room rerun of build, program, and ROM validation succeeds.
1. Documentation is sufficient for repeatable operation without tribal knowledge.

**Relevant files**
- /Users/rowe/Software/FPGA/Atari7800_AstroCart_V2/menu/menu.bas - Keep trigger protocol and menu behavior stable while hardware evolves.
- /Users/rowe/Software/FPGA/Atari7800_AstroCart_V2/menu/build.sh - Preserve deterministic menu build artifact generation for each hardware test cycle.
- /Users/rowe/Software/FPGA/Atari7800_AstroCart_V2/build_gowin.sh - Update project source inclusion and synthesis flow for the new HDL set.
- /Users/rowe/Software/FPGA/Atari7800_AstroCart_V2/program.sh - Keep programming flow consistent for rapid board iteration.
- /Users/rowe/Software/FPGA/Atari7800_AstroCart_V2/write_games_to_sd.py - Keep as regression media generator and fallback path while FAT path is integrated.
- /Users/rowe/Software/FPGA/Atari7800_AstroCart_V2/atari.cst - Revalidate constraints and signal timing assumptions against the corrected PCB.

**Verification**
1. Build verification: run menu build and FPGA synthesis/program flow, confirming artifacts are generated and programming completes without manual patching.
1. Hardware-path verification: validate PSRAM read/write correctness and SD block-read determinism before enabling full handoff.
1. Functional verification sequence:
1. AstroWing boots from SD to PSRAM with working Pokey audio.
1. Choplifter boots with correct 32KB mapping behavior.
1. Commando validates supercart banking + Pokey@4000 path.
1. ARTI validates supercart + Pokey@450 + RAM@4000 integration.
1. Reliability verification: repeated game-load loops with zero silent load truncation, zero mapper regressions, and stable audio.

**Decisions**
- Selected SD strategy: Softcore + FAT filesystem.
- Selected first milestone: AstroWing from SD->PSRAM with Pokey audio.
- Selected observability level: LED-only debug for phase 0.
- Included scope: deterministic SD/FAT-to-PSRAM loading, mapper correctness, Pokey correctness, handoff stability.
- Excluded initial scope: richer debug register maps, UI-level filesystem browsing polish, nonessential feature expansion.

**Further Considerations**
1. Softcore selection decision package: compare one minimal-RISC option versus one vendor-friendly option using LUT/RAM/timing headroom and firmware complexity, then lock one before implementation.
1. FAT deployment path: start with read-only FAT32 support and contiguous-file optimization first; defer fragmented-file edge cases until baseline stability is proven.
1. Fallback strategy: keep raw-slot compatibility enabled until ARTI passes full reliability sweeps on FAT path.
