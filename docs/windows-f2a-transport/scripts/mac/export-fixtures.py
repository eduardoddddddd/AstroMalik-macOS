"""Export authentic Mac outputs from explicit binaries into a fresh directory.

No building, patching, network, personal userdata or invented expected values.
Only result JSON is compared; raw stdout/stderr/progress is kept as evidence.
"""
from __future__ import annotations
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import queue
import shutil
import subprocess
import tempfile
import threading
import time

BASE = "edd8912847723707aaf52f538b5f5b5a669c4f82"


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def dump(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def git(repo, *args):
    return subprocess.check_output(["git", "-C", str(repo), *args], text=True).strip()


def provenance_repo(repo, baseline=False):
    commit = git(repo, "rev-parse", "HEAD")
    subprocess.run(["git", "-C", str(repo), "diff", "--exit-code", "HEAD", "--", "Sources", "Package.swift", "Package.resolved"], check=True,
                   stdout=subprocess.DEVNULL)
    if baseline:
        subprocess.run(["git", "-C", str(repo), "merge-base", "--is-ancestor", BASE, "HEAD"], check=True)
        subprocess.run(["git", "-C", str(repo), "diff", "--exit-code", BASE, "--", "Sources", "Package.swift", "Package.resolved"], check=True,
                       stdout=subprocess.DEVNULL)
    resources = repo / "Sources/AstroMalik/Resources"
    resource_hashes = {str(p.relative_to(repo)).replace(os.sep, "/"): sha(p)
                       for p in sorted(resources.rglob("*")) if p.is_file() and (p.suffix == ".se1" or p.name == "corpus.db")}
    source_paths = list((repo / "Sources/CSwissEph").rglob("*.c")) + list((repo / "Sources/CSwissEph").rglob("*.h"))
    source_paths += [repo / name for name in ("Sources/AstroMalik/EngineRPC.swift", "Sources/AstroMalik/AstroMalikCLIRunner.swift",
                                              "Sources/AstroMalikCLI/main.swift", "Sources/AstroMalikEngineHost/EngineHost.swift")]
    sources = {str(p.relative_to(repo)).replace(os.sep, "/"): sha(p) for p in sorted(source_paths) if p.is_file()}
    return {"commit": commit, "engineInputsClean": True, "resourceSha256": resource_hashes, "sourceSha256": sources}


def bundle_hashes(directory, source_resources):
    files = [p for p in directory.rglob("*") if p.is_file() and (p.suffix == ".se1" or p.name == "corpus.db")]
    hashes = {}
    for path in files:
        digest = sha(path)
        if path.name in hashes and hashes[path.name] != digest:
            raise RuntimeError(f"Conflicting resource copies in bundle: {path.name}")
        hashes[path.name] = digest
    expected = {Path(name).name: digest for name, digest in source_resources.items()}
    if hashes != expected:
        raise RuntimeError("Actual bundle corpus/ephemeris hashes differ from its Mac source resources")
    return hashes


class Host:
    def __init__(self, binary, directory, evidence, environment, timeout):
        self.evidence, self.timeout = evidence, timeout
        self.log = (evidence / "rpc-stderr.log").open("wb")
        self.process = subprocess.Popen([str(binary), "--data-dir", str(directory)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=self.log, env=environment, cwd=directory)
        self.messages, self.next_id, self.raw = queue.Queue(), 0, []
        def reader():
            try:
                for line in self.process.stdout:
                    self.raw.append(line)
                    self.messages.put(json.loads(line))
            except Exception as error:
                self.messages.put(error)
            finally:
                self.messages.put(EOFError("Mac RPC exited"))
        self.reader = threading.Thread(target=reader, daemon=True)
        self.reader.start()

    def call(self, request):
        self.next_id += 1
        message = dict(request, id=self.next_id)
        self.process.stdin.write((json.dumps(message, ensure_ascii=False) + "\n").encode("utf-8"))
        self.process.stdin.flush()
        progress = []
        deadline = time.monotonic() + self.timeout
        while True:
            try:
                reply = self.messages.get(timeout=max(.001, deadline - time.monotonic()))
            except queue.Empty as error:
                raise TimeoutError(f"{request['method']}: no terminal response within {self.timeout}s") from error
            if isinstance(reply, BaseException):
                raise reply
            if reply.get("id") != message["id"]:
                raise RuntimeError(f"Uncorrelated reply: {reply}")
            if "progress" in reply:
                progress.append(reply)
                continue
            if "error" in reply:
                raise RuntimeError(f"{request['method']}: {reply['error']}")
            return reply["result"], progress

    def close(self):
        try:
            self.process.stdin.close()
        except BrokenPipeError:
            pass
        try:
            code = self.process.wait(timeout=30)
        except subprocess.TimeoutExpired:
            self.process.kill()  # Only our isolated child process.
            code = self.process.wait()
        self.reader.join(timeout=10)
        self.log.close()
        (self.evidence / "rpc-stdout.jsonl").write_bytes(b"".join(self.raw))
        if code:
            raise RuntimeError(f"RPC exit {code}")


def run(args):
    if platform.system() != "Darwin":
        raise SystemExit("Mac reference generation requires Darwin; Windows observations are not golden fixtures")
    manifest = json.loads(args.template.read_text(encoding="utf-8"))
    if manifest["schemaVersion"] != 1:
        raise SystemExit("Unsupported manifest schema")
    args.output.mkdir(parents=True, exist_ok=False)
    evidence = args.output / "evidence"
    evidence.mkdir()
    environment = os.environ.copy()
    environment["TZ"] = "UTC"
    os.environ["TZ"] = "UTC"
    time.tzset()
    cli_info = provenance_repo(args.cli_repo, baseline=True)
    rpc_info = provenance_repo(args.rpc_repo)
    cli_info.update(binarySha256=sha(args.cli), role="Original Mac CLI baseline")
    rpc_info.update(binarySha256=sha(args.rpc), role="F3 RPC PR#3; not merged into original baseline")
    cli_info["bundleResourceSha256"] = bundle_hashes(args.cli_resources, cli_info["resourceSha256"])
    rpc_info["bundleResourceSha256"] = bundle_hashes(args.rpc_resources, rpc_info["resourceSha256"])
    if args.rpc_host_source:
        rpc_info["hostSourceSha256"] = sha(args.rpc_host_source)
        rpc_info["hostSourceMeaning"] = "Actual Mac build wrapper source; no Windows source equality assumed"
        (evidence / "mac-rpc-host-source.swift").write_bytes(args.rpc_host_source.read_bytes())
    baseline_probe = json.loads(args.backend_probe.read_text(encoding="utf-8"))
    if baseline_probe.get("platform") != "macOS" or not baseline_probe.get("probes") or any(p.get("backend") != "swiss-files" or p.get("returnedFlags", -1) < 0 for p in baseline_probe["probes"]):
        raise RuntimeError("Backend probe must contain actual successful Mac Swiss returned flags")
    dump(evidence / "input-template.json", manifest)
    host = None
    try:
        with tempfile.TemporaryDirectory(prefix="astromalik-f2-mac-") as temporary:
            directory = Path(temporary)
            host = Host(args.rpc, directory, evidence, environment, args.timeout)
            hello, _ = host.call({"method": "system.hello", "params": {}})
            dump(evidence / "hello.json", hello)
            if hello["networkEnabled"] or hello["ephemerisBackend"] != "swiss-files":
                raise RuntimeError("Expected local RPC with bundled Swiss files")
            if baseline_probe["swissVersion"] != hello["swissVersion"]:
                raise RuntimeError("Baseline observed Swiss version differs from RPC version")
            war_case = next(c for c in manifest["cases"] if c["id"] == "natal-war1940-control")
            war_chart, progress = host.call(war_case["request"])
            manifest["inputs"]["charts"].append(war_chart)
            war_path = args.output / war_case["expected"]
            dump(war_path, war_chart)
            war_case["expectedSha256"] = sha(war_path)
            host.call({"method": "charts.importFromMac", "params": {"charts": manifest["inputs"]["charts"]}})
            user_db = directory / "user.db"
            if not user_db.is_file():
                raise RuntimeError("Isolated imported user.db missing")
            # --user-db does not override the original CLI's writable corpus cache.
            # Pin a temporary copy of the verified bundle, never personal Application Support.
            corpus_sources = list(args.cli_resources.rglob("corpus.db"))
            if len(corpus_sources) != 1:
                raise RuntimeError("Require one actual CLI bundled corpus")
            corpus_db = directory / "corpus.db"
            shutil.copyfile(corpus_sources[0], corpus_db)
            effective_corpus_hash = sha(corpus_db)
            for case in manifest["cases"]:
                if case is war_case:
                    continue
                print(f"Export {case['id']}", flush=True)
                if case["transport"] == "cli":
                    argv = [a.replace("{userDb}", str(user_db)).replace("{corpusDb}", str(corpus_db)) for a in case["argv"]]
                    if "--no-network" not in argv or "--allow-network" in argv or "--corpus-db" not in argv:
                        raise RuntimeError("CLI network/corpus isolation policy missing")
                    completed = subprocess.run([str(args.cli), *argv], env=environment, cwd=directory,
                                               capture_output=True, timeout=args.timeout)
                    (evidence / f"{case['id']}.stdout.json").write_bytes(completed.stdout)
                    (evidence / f"{case['id']}.stderr.log").write_bytes(completed.stderr)
                    if completed.returncode:
                        raise RuntimeError(f"{case['id']}: CLI exit {completed.returncode}; see stderr evidence")
                    result = json.loads(completed.stdout)
                    if argv[0] == "astrocartography":
                        if result.get("kind") != "astromalik.astrocartography":
                            raise RuntimeError("Expected original AstroExportDocumentJSON")
                    elif result.get("networkUsed") is not False:
                        raise RuntimeError("CLI did not confirm networkUsed=false")
                    case["provenanceRef"] = "cli"
                else:
                    for setup in case.get("setup", []):
                        host.call(setup)
                    result, progress = host.call(case["request"])
                    dump(evidence / f"{case['id']}.progress.json", progress)
                    case["provenanceRef"] = "rpc"
                path = args.output / case["expected"]
                dump(path, result)
                case["expectedSha256"] = sha(path)
            host.close()
            host = None
        war_case["provenanceRef"] = "rpc"
        manifest["kind"] = "mac-reference"
        manifest["provenance"].update(platform="macOS", macCommit=BASE, windowsBaseCommit=BASE, swissVersion=hello["swissVersion"], ephemerisBackend="swiss-files", cli=cli_info, rpc=rpc_info,
                                       generatedAt=datetime.now(timezone.utc).isoformat(), operatingSystem=platform.platform(),
                                       timezone="UTC", noNetwork=True, isolatedUserData=True, hello=hello,
                                       backendProbe=baseline_probe, inputTemplateSha256=sha(args.template),
                                       effectiveCLICorpusSha256=effective_corpus_hash,
                                       inputChartsBackend="F1 Moshier inputs retained; war control computed by F3 Swiss files")
        dump(args.output / "manifest.json", manifest)
        (args.output / "VERSION").write_text(f"baseline {BASE}\ncli {cli_info['commit']}\nrpc {rpc_info['commit']}\nbackend swiss-files\n", encoding="utf-8")
        hashes = [(str(p.relative_to(args.output)).replace(os.sep, "/"), sha(p)) for p in sorted(args.output.rglob("*")) if p.is_file()]
        (args.output / "SHA256SUMS").write_text("".join(f"{digest}  {name}\n" for name, digest in hashes), encoding="utf-8")
        print(f"Exported {len(manifest['cases'])} authentic Mac cases: {args.output}", flush=True)
    except BaseException as error:
        dump(args.output / "failure.json", {"status": "incomplete-not-accepted", "error": str(error)})
        raise
    finally:
        if host is not None:
            try:
                host.close()
            except Exception as cleanup_error:
                dump(evidence / "cleanup-error.json", {"error": str(cleanup_error)})


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True, help="New directory; refusing to replace references")
    parser.add_argument("--cli", type=Path, required=True)
    parser.add_argument("--rpc", type=Path, required=True)
    parser.add_argument("--cli-repo", type=Path, required=True)
    parser.add_argument("--rpc-repo", type=Path, required=True)
    parser.add_argument("--backend-probe", type=Path, required=True, help="Observed Swiss returned flags from baseline, not configured hello label")
    parser.add_argument("--cli-resources", type=Path, required=True, help="Actual CLI .bundle resources root")
    parser.add_argument("--rpc-resources", type=Path, required=True, help="Actual RPC bundle/resources root")
    parser.add_argument("--rpc-host-source", type=Path, help="Actual compiled Mac host wrapper source, preserved as evidence")
    parser.add_argument("--timeout", type=int, default=1800, help="Per calculation deadline, in seconds")
    args = parser.parse_args()
    for key in ("template", "output", "cli", "rpc", "cli_repo", "rpc_repo", "backend_probe", "cli_resources", "rpc_resources", "rpc_host_source"):
        if getattr(args, key) is not None:
            setattr(args, key, getattr(args, key).resolve())
    run(args)


if __name__ == "__main__":
    main()
