# `ss -tnp` is blind across WSL1 shell sessions

**Symptom:** A service is running in WSL (uvicorn, dev server, anything binding a port). From a *different* WSL shell session you run `ss -tnp 'sport = :8082'` to inspect the listening socket — and it returns nothing. Or worse, it returns nothing for established connections to that service either.

But: `curl http://localhost:8082/` from the same shell *does* work — the connection succeeds, the service responds. So the socket clearly exists, but `ss` (and `lsof -i`, and `/proc/net/tcp`) don't show it.

**Context:** WSL1 specifically. WSL2 has a real shared kernel namespace and behaves like normal Linux here. WSL1's "Linux subsystem" presents per-shell kernel state in some areas — `/proc/net/tcp` reflects only your own process tree's connections, not all sockets on the system.

**Cause:** WSL1 emulates Linux syscalls via the LXSS service. Each WSL shell session can be a separate `init` instance, and the network-namespace abstraction doesn't fully unify across them. `ss`, `lsof`, and `/proc/net/tcp` all read from kernel-side state that's session-scoped on WSL1, even though the actual network stack is Windows's underneath and the socket *does* listen system-wide.

**Implication for diagnostics:** any test that says "I'll check whether a service is listening by running `ss` from another shell" will give false negatives on WSL1. You may convince yourself the service is down when it's actually running and reachable.

**Fix / workaround:** Don't probe with `ss`. Use an HTTP probe instead — it goes through the actual socket layer and works regardless of which WSL session you started the service from:

```bash
listening() {
    local code
    code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 \
        "http://localhost:8082/" 2>/dev/null) || code="000"
    [ "$code" != "000" ] && [ -n "$code" ]
}
```

`bin/claude-nim` uses exactly this pattern (line 16-23). The launcher's comment notes the WSL1 limitation in the function docstring.

**Implication for validation tests:** if you're writing a "did this leak" test that depends on inspecting `/proc/net/tcp` from a different shell, the test is best-effort on WSL1, not airtight. We hit this directly in V2 (no-leak validation): the `/proc/net/tcp*` snapshot is taken from the same shell as the test command, which works, but if you split it into background polling from a sibling shell, the polling sees nothing and you get false-pass results.

**Verified on:** WSL1 Ubuntu 24.04, kernel 5.10-microsoft-standard-WSL2 (yes, WSL1 reports a WSL2-flavored kernel string — that's an unrelated WSL1 quirk). Repeatable: start `nohup uvicorn ... &` in shell A, run `ss -tnp 'sport = :8082'` in shell B — empty.

**Learned:** WSL1 is a syscall translation layer, not a kernel. Anything that reads kernel-side aggregate state can be inconsistent. **Test reachability through the actual transport (HTTP, TCP `nc`), not through introspection.** The introspection answers may be lies.
