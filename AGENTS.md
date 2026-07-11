# Agent guide: docker-library/rabbitmq

Orientation for an AI working in this repo. It documents how the repo is
*mechanically* built and the traps that are not obvious from the source. It does
not cover maintainer intent or PR conventions — those belong to the
docker-library maintainers.

## What this repo is

The source for the [`rabbitmq` Docker Official Image](https://hub.docker.com/_/rabbitmq/).
It does not build one Dockerfile per hand — it *generates* a matrix of
Dockerfiles (RabbitMQ version × OS variant × management sub-variant) from a
small set of templates.

`README.md` is a generated stub for Docker Hub users; it documents nothing about
working in the repo. The real "source of truth" manifest that Docker Hub
consumes lives downstream in
[`docker-library/official-images`](https://github.com/docker-library/official-images)
as `library/rabbitmq`, produced by this repo's `generate-stackbrew-library.sh`.

## The golden rule

**Never edit the generated `4.x/<variant>/` files directly.** They carry a
`# NOTE: THIS DOCKERFILE IS GENERATED ... PLEASE DO NOT EDIT IT DIRECTLY` header
and are overwritten on every regeneration.

Edit the *inputs*, then regenerate:

- Version/pin data → `versions.json` (and `versions.sh`, which produces it).
- Dockerfile content → `Dockerfile-<variant>.template` and
  `Dockerfile-management.template`.
- Then run `./apply-templates.sh` and commit the regenerated `4.x/` output
  together with your template change.

CI enforces this. `.github/workflows/verify-templating.yml` runs
`./apply-templates.sh` then `git diff --exit-code` — if the committed generated
files don't match what the templates produce, the build fails.

## The generation pipeline

- `versions.sh [version...]` — fetches upstream versions (RabbitMQ, Erlang/OTP,
  OpenSSL, gosu, rabbitmqadmin) and writes pinned versions + SHA256s into
  `versions.json`. Two distinct kinds of pin live in associative arrays at the
  top, keyed by RabbitMQ minor line — do not confuse them:
  - **OS base-image versions**: `alpineVersions`, `ubuntuVersions`,
    `amazonlinuxVersions` (e.g. `[4.3]='2023'`). Edit these to change the OS a
    variant builds on.
  - **Toolchain major versions** (not OS versions): `otpMajors` (Erlang/OTP
    major, "Maximum supported Erlang/OTP") and `opensslMajors` (OpenSSL major).
    `versions.sh` resolves each to the latest matching upstream release.
- `apply-templates.sh [version...]` — renders each `Dockerfile-<variant>.template`
  through jq-template (`.jq-template.awk`, a gawk script) into
  `4.x/<variant>/Dockerfile` and `4.x/<variant>/management/Dockerfile`, and
  copies `docker-entrypoint.sh` + `conf.d/*.conf` in. Requires `versions.json`
  to exist first.
- `update.sh [version...]` — the canonical wrapper: runs `versions.sh` then
  `apply-templates.sh`.
- `generate-stackbrew-library.sh` — emits the official-images manifest (tags +
  architectures + git commit + directory) to stdout.

Templates are jq-template: `{{ ... }}` blocks are jq expressions with repo data
(`.version`, `.openssl`, `.otp`, `env.variant`, etc.) in scope. A trailing `-`
inside a block (`{{ ... -}}`) trims following whitespace.

## Adding or changing an OS variant

A variant named `X` needs, consistently:

1. A version entry in `versions.sh` — an `XVersions` associative array plus its
   export and its `X: { version: env.XVersion }` entry in the `jq` that builds
   `versions.json`. Run `./versions.sh` to populate `versions.json`.
2. `Dockerfile-X.template` — the multi-stage build for that base image.
3. `X` added to the variant loop in **both** `apply-templates.sh` and
   `generate-stackbrew-library.sh` (the two lists must agree).
4. A branch in `Dockerfile-management.template`'s `if env.variant == ...` chain
   for how that base installs `rabbitmqadmin`.
5. `./apply-templates.sh`, then commit the regenerated `4.x/X/` dirs.

Notes that bit us and will bite again:

- **`defaultVariant='ubuntu'`** in `generate-stackbrew-library.sh`. The default
  variant's tags are *untagged* (`4.3`, not `4.3-ubuntu`); every other variant
  is suffixed (`4.3-<variant>`). `Dockerfile-management.template`'s `FROM` relies
  on this — the base image reference is untagged only for ubuntu.
- **Alpine swaps `gosu` for `su-exec`** via a `sed 's/gosu/su-exec/g'` on the
  copied `docker-entrypoint.sh`, applied only when `variant = alpine` in
  `apply-templates.sh`. Other variants keep `gosu`.
- The generated dirs are marked `linguist-generated` in `.gitattributes`.

## OS-specific gotchas (Amazon Linux 2023 / `dnf`)

Verified while adding the amazonlinux variant; not obvious and cost real build
iterations:

- AL2023 ships **`-minimal`** packages that *conflict* with their full versions.
  `gnupg2-minimal` lacks `dirmngr` (needed for `gpg --keyserver ... --recv-keys`),
  so install the full package with `dnf install -y --allowerasing gnupg2`. The
  base already provides the `curl` binary via `curl-minimal`; installing full
  `curl` conflicts — omit it rather than install it.
- The AL2023 base is minimal — many tools ubuntu's base ships are absent and
  must be installed explicitly. Distinguish three categories, because they belong
  in different build stages and have different cleanup rules:
  - **Build-time toolchain** (builder stages only, never the final stage):
    `gcc gcc-c++ make autoconf ncurses-devel`.
  - **Transient fetch/verify tools** (install then remove in the same final RUN):
    `wget`, `xz`. See the runtime-parity rule below.
  - **Genuine runtime dependencies** (install and keep in the final stage):
    `findutils` (`docker-entrypoint.sh` runs `find` at container start — AL2023
    has no `find` by default, whereas ubuntu's base does), `hostname` (the
    entrypoint calls `hostname`/`hostname -s`), `procps-ng` (for `ps`),
    `shadow-utils` (for the build-time `groupadd`/`useradd`; not removable
    without a `dnf clean all`, so left installed), and `tar`.
- **Runtime parity with ubuntu is the rule for what stays installed.** The
  amazonlinux final image should expose the same runtime toolset as the shipped
  ubuntu image. Verified against `rabbitmq:4.3`: ubuntu keeps `tar`, `find`,
  `gosu`, `hostname`, `ps` and purges `wget` + `xz`. So the amazonlinux cleanup
  is `dnf remove -y wget xz; dnf clean all` — **not** `tar`/`findutils`, which
  ubuntu keeps and the entrypoint needs. (To decide a tool's fate, check the
  shipped ubuntu image: `docker run --rm rabbitmq:<ver> command -v <tool>`.)
- `dnf remove` cannot remove **protected** packages: it refuses to remove
  `gnupg2` because `dnf` itself depends on it. So the full `gnupg2` (installed
  via `--allowerasing` to get `dirmngr`, replacing `gnupg2-minimal`) is stuck in
  the final image — the one unavoidable divergence from ubuntu, which purges
  `gnupg`. A `dnf remove` list that includes a protected package aborts and
  removes *nothing*, so never mix `gnupg2` into the cleanup line.
- Every final-stage `dnf install` must be paired with a `dnf clean all` **in the
  same RUN** — a later RUN's clean cannot reclaim an earlier layer's
  `/var/cache/dnf`.
- **`gosu` is not packaged.** It is downloaded from the tianon/gosu GitHub
  release and verified by SHA256 (pinned in `versions.json`, arch-mapped in the
  template). Note `versions.json` uses arch key `arm64` for gosu but `arm64v8`
  for rabbitmqadmin — the two `def uname_arches` maps in the templates differ
  accordingly, so do not copy one map into the other's block.
- Arch detection uses `uname -m` (`x86_64` / `aarch64`) — there is no `dpkg`
  (`--print-architecture`) or apk (`--print-arch`).

## Validating locally

- **Build a variant for real** before trusting a change (each compiles OpenSSL +
  Erlang/OTP from source, so it's slow). The management sub-variant `FROM`s the
  base image by the exact tag `generate-stackbrew-library.sh` would publish, so
  tag the base you build to match, or the management build won't find it:
  - Non-default variant (e.g. amazonlinux, alpine) — the base tag is suffixed:
    ```
    docker build -t rabbitmq:4.3-amazonlinux 4.3/amazonlinux
    docker build -t rabbitmq:4.3-management-amazonlinux 4.3/amazonlinux/management
    ```
  - Default variant (ubuntu) — the base tag is **untagged** (see `defaultVariant`
    above), so its management image `FROM`s `rabbitmq:4.3`, not
    `rabbitmq:4.3-ubuntu`:
    ```
    docker build -t rabbitmq:4.3 4.3/ubuntu
    docker build -t rabbitmq:4.3-management 4.3/ubuntu/management
    ```
- **Check the downstream manifest gate.** The acceptance checks that gate the
  official-images PR are `naughty-from.sh`, `naughty-sharedtags.sh`, and
  `naughty-constraints.sh` in the official-images repo, run via `bashbrew`. A
  base image referenced in `FROM` must itself be an official image supporting
  the target architectures, or `naughty-from.sh` rejects it. Generate the
  candidate manifest with `./generate-stackbrew-library.sh` and validate it with
  a local `bashbrew` build against the official-images `oi/` scripts.
