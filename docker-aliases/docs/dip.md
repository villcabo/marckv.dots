# `dip` — which container has this IP

Finds the container behind an address. The question usually comes from a log
line: nginx says `172.18.0.5` timed out, and you want to know who that is.

- **Source:** [`commands/dip.sh`](../commands/dip.sh)
- **Completion:** [`completions/dip.bash`](../completions/dip.bash) · [`completions/dip.zsh`](../completions/dip.zsh)
- **Shells:** bash and zsh

---

## Usage

```
dip [address | pattern]
```

## Flags

| Flag | Meaning |
|---|---|
| `-h`, `--help` | Show the built-in help |

## Matching

Three kinds of query, and the difference between the first two is the whole
reason this command exists:

| You type | It matches | Why |
|---|---|---|
| `172.18.0.5` | **exactly** that address | as a substring, `.5` would also match `.50` |
| `172.18.0` | the subnet `172.18.0.*` | on an octet boundary: never `172.180.*` |
| `172.18.0.` | the same subnet | a trailing dot is a subnet being typed |
| `nginx` | names and networks, as a regex | anything that is not an address |
| *(nothing)* | every address on the host | |

A full address matched as a substring is the classic way an IP search lies:
`172.18.0.5` is a prefix of `172.18.0.50`, and a log line about one would blame
the other. The same goes for prefixes — `172.18` must mean `172.18.*`, not also
`172.180.*`. Both are covered by tests that plant exactly those addresses.

## Output

```
  [docker] docker ip  ·  3 of 39  ·  filter: nginx-api-ws-nginx
  IP          NETWORK               PROJECT       SERVICE  STATUS   NAME
  10.78.10.2  nginx-api-ws_default  nginx-api-ws  nginx    running  nginx-api-ws-nginx-1
  10.100.4.2  nginx-api-ws_grafana  nginx-api-ws  nginx    running  nginx-api-ws-nginx-1
  10.78.20.2  nginx-api-ws_scan     nginx-api-ws  nginx    running  nginx-api-ws-nginx-1
```

**One row per container per network.** A container on three networks holds
three addresses, and the one in your log may be any of them.

**The host network shows a dash.** docker reports a host-network container's
address as the literal text `invalid IP` — not as empty. Printed raw it reads
like an address; `dip` shows `—` instead, so it can never be mistaken for one or
matched as one.

`PROJECT` and `SERVICE` come from the compose labels, and are `—` for a
container compose did not create.

## Examples

```bash
dip 172.18.0.5          # who is behind the address in that log line
dip 10.100              # everything on that subnet
dip keycloak            # every address keycloak holds
dip _backend            # who is attached to the backend network
dip 10.0.0.9 || echo "address is free"
```

## Exit codes

| Code | When |
|---|---|
| 0 | Something matched, or no query was given |
| 1 | A query matched nothing, an unknown flag, or no daemon |

Exiting 1 on no match is deliberate: `dip` is a lookup, and a lookup that found
nothing is a result a script should be able to test for.

## Performance

One `docker ps` and one `docker inspect` for every running container together —
never one call per row. Measured on a host with 27 containers and 39 addresses:
**160–220 ms**, against ~210 ms for those two docker calls alone. The command
costs what docker costs.

## Notes

- **No preview, no confirmation.** It only reads. A scope line, like `dps`.
- Stopped containers have no address, so only running ones are inspected.
- `docker inspect --format` does **not** turn `\t` into a tab, unlike
  `docker ps --format`. The template uses `{{"\t"}}` — a Go string literal —
  instead. Copying the `dps` pattern would have split every row wrong.

## Related

- [`dnet`](dnet.md) — the networks themselves, with their subnets
- [`dps`](dps.md) — every container, with its ports
- [`dx`](dx.md) — once you know which container, get inside it
