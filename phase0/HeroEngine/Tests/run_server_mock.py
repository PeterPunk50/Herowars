#!/usr/bin/env python3
"""Builds _server_mock.gen.luau (mock Roblox + the real Roblox-side scripts) and runs it with the Luau CLI.
Usage (repo root): LUAU=/path/to/luau python3 phase0/HeroEngine/Tests/run_server_mock.py"""
import os, subprocess, sys
here = os.path.dirname(os.path.abspath(__file__))
root = os.path.dirname(os.path.dirname(here))  # phase0/
def src(rel): return open(os.path.join(root, rel)).read()
def wrap(parent, name, rel, parent_expr):
    # Each Roblox script becomes a function with its own `script` (a mock instance in the right folder).
    return (f"robloxModule({parent_expr}, {name!r}, function()\n local script = {parent_expr}.{name}\n"
            + src(rel) + "\nend)\n")
parts = [src("HeroEngine/Tests/server_mock_head.luau"),
         wrap("Adapters", "NetworkService", "HeroEngine/RobloxAdapters/NetworkService.luau", "Adapters"),
         wrap("Adapters", "HitboxAdapter", "HeroEngine/RobloxAdapters/HitboxAdapter.luau", "Adapters"),
         "local SSS = inst('Folder', 'ServerScriptService')\n",
         wrap("SSS", "Phase0Server", "TestPlace/Server/Phase0Server.server.luau", "SSS"),
         "require(SSS.Phase0Server)\n",
         src("HeroEngine/Tests/server_mock_tail.luau")]
out = os.path.join(here, "_server_mock.gen.luau")
open(out, "w").write("\n".join(parts))
sys.exit(subprocess.call([os.environ.get("LUAU", "luau"), out], cwd=here))
