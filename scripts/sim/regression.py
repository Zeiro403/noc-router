
#!/usr/bin/env python3
"""NoC regression runner. Each test/seed runs in a fresh simulation process."""

import argparse
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

DIRECTED = [
    "basic",
    "local",
    "parallel",
    "routing",
    "contention",
    "backpressure",
    "fifo_stress",
    "back_to_back",
    "reset",
    "fairness",
]

SMOKE = ["basic", "local", "parallel"]


def run_command(command, timeout):
    return subprocess.run(
        command,
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


def main():
    parser = argparse.ArgumentParser(
        description="NoC Router Regression Runner"
    )

    parser.add_argument(
        "--suite",
        choices=["smoke", "standard", "full"],
        default="smoke",
        help="Regression suite to execute",
    )

    parser.add_argument(
        "--seeds",
        type=int,
        default=20,
        help="Number of pseudorandom seeds for full regression",
    )

    args = parser.parse_args()

    if args.seeds < 1:
        parser.error("--seeds must be at least 1")

    suites = {
        "smoke": SMOKE,
        "standard": DIRECTED,
        "full": DIRECTED,
    }

    runs = [(name, 1) for name in suites[args.suite]]

    if args.suite == "full":
        runs.extend(
            ("random", seed)
            for seed in range(1, args.seeds + 1)
        )

    logdir = ROOT / "results" / "simulation" / "logs"
    logdir.mkdir(parents=True, exist_ok=True)

    print(f"\nBuilding NoC router simulation...", flush=True)

    try:
        build = run_command(["make", "build"], timeout=300)
    except subprocess.TimeoutExpired:
        print("BUILD TIMEOUT", file=sys.stderr)
        return 1

    build_log = logdir / "build.log"
    build_log.write_text(
        build.stdout + build.stderr,
        encoding="utf-8",
    )

    if build.returncode != 0:
        print(f"BUILD FAILED: {build_log}", file=sys.stderr)
        print(build.stdout + build.stderr)
        return 1

    print("Build successful.\n", flush=True)

    failed = 0

    print("========== NoC REGRESSION ==========")
    print(f"Suite : {args.suite}")
    print(f"Tests : {len(runs)}")
    print("====================================")

    for name, seed in runs:
        start = time.monotonic()

        try:
            proc = run_command(
                [
                    "make",
                    "--no-print-directory",
                    "test",
                    f"TEST={name}",
                    f"SEED={seed}",
                ],
                timeout=180,
            )

            output = proc.stdout + proc.stderr

            passed = (
                proc.returncode == 0
                and "SCOREBOARD: ALL PACKETS MATCHED" in proc.stdout
                and f"TEST {name} PASSED" in proc.stdout
            )

        except subprocess.TimeoutExpired as exc:
            output = f"TIMEOUT: {exc}\n"
            passed = False

        elapsed = time.monotonic() - start

        log_path = logdir / f"{name}_seed{seed}.log"
        log_path.write_text(output, encoding="utf-8")

        if not passed:
            failed += 1

        status = "PASS" if passed else "FAIL"

        print(
            f"{name:<20} "
            f"seed={seed:<5} "
            f"{status:<5} "
            f"{elapsed:.2f}s",
            flush=True,
        )

        if not passed:
            print(f"  Log: {log_path}")

    total = len(runs)
    passed_count = total - failed

    print("\n========== REGRESSION SUMMARY ==========")
    print(f"Suite  : {args.suite}")
    print(f"Total  : {total}")
    print(f"Passed : {passed_count}")
    print(f"Failed : {failed}")
    print("========================================")

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
