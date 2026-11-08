# Decision Guide: Profile First, Then Choose the Target

## Profile before rewriting

A rewrite is expensive. Before proposing one, establish what is actually slow:

- **CPU-bound** — a loop, parse, or compute step pegs a core.
- **I/O-bound** — waiting on disk, network, or a subprocess.
- **Startup-bound** — the tool takes a long time just to begin (interpreter + imports).
- **Memory-bound** — large intermediate data structures.

Measure, do not guess. A five-minute profiling pass (or even timing the obvious stages) beats rewriting the wrong layer.

## Match the fix to the bottleneck

- Startup + memory overhead of a language runtime -> a compiled binary often wins.
- A thin serving/HTTP layer -> a small fast server (Rust/Go) is a natural fit.
- A heavy numeric loop in Python -> numpy/Numba/C extension, or move that one loop to Rust/C.
- A slow subprocess chain -> parallelize or pipeline it, or replace only the bottleneck tool.

## Choosing the target language

- **Rust** — best when you want a single small binary, low memory, fast startup, and CPU-bound performance, and you accept the build toolchain and borrow-checker learning curve. Good for a server, worker, or parsing loop.
- **Go** — single binary, fast compile, simple concurrency, garbage-collected. Often faster to write than Rust; slightly larger binaries and less predictable latency. A good default when Rust feels like overkill.
- **C/C++** — only when the project already lives there, needs a native library/FFI, or has hard real-time constraints.
- **Optimize the existing language** — often the cheapest win. For Python: PyPy, asyncio, multiprocessing, numpy/Numba, moving a hot function to a C extension. Try this before a full rewrite when the bottleneck is localized.

## Scope rule

Rewrite the smallest layer that removes the bottleneck. Keep the rest untouched, and keep its contract identical so nothing downstream needs to change. If you cannot name the layer you are replacing and why it is the bottleneck, do not start the rewrite.