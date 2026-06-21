# sml-web

[![CI](https://github.com/sjqtentacles/sml-web/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-web/actions/workflows/ci.yml)

The umbrella of the sjqtentacles pure-SML web stack: one `request -> response`
application assembled from a router and a middleware stack, with content
negotiation helpers. It adds no protocol logic of its own — it wires the
tier-2 libraries into a single pure handler you can test end-to-end over
hand-built requests, with no sockets, threads, or OS I/O. Dual-compiler:
**MLton + Poly/ML**.

## What it ties together

- [sml-router](https://github.com/sjqtentacles/sml-router) — method + path
  routing with params and wildcards.
- [sml-middleware](https://github.com/sjqtentacles/sml-middleware) — composable
  `handler -> handler` wrappers (logging, error catching, headers, static files).
- [sml-negotiate](https://github.com/sjqtentacles/sml-negotiate) — `Accept*`
  content negotiation.
- [sml-html](https://github.com/sjqtentacles/sml-html),
  [sml-forms](https://github.com/sjqtentacles/sml-forms),
  [sml-session](https://github.com/sjqtentacles/sml-session) — rendering, typed
  body decoding, sessions, all available to handlers.
- [sml-http](https://github.com/sjqtentacles/sml-http) — the request/response
  model underneath everything.

## API

```sml
type app

val make : { middleware : Middleware.middleware list   (* outermost first *)
           , routes : Router.route list
           , notFound : Http.request -> Http.response } -> app

val run        : app -> Http.request -> Http.response
val runString  : app -> string -> Http.response option   (* parse + run *)

val negotiateMedia    : Http.request -> string list -> string option
val negotiateLanguage : Http.request -> string list -> string option
val negotiateEncoding : Http.request -> string list -> string option
```

## Example

```sml
val app =
  Web.make
    { middleware =
        [ Middleware.logTo log fmt
        , Middleware.catchErrors (fn _ => Http.text 500 "Internal Error")
        , Middleware.addHeader "X-Powered-By" "sml-web" ]
    , routes =
        [ Router.get "/" home
        , Router.get "/greet/:name" greet ]
    , notFound = fn _ => Http.text 404 "Not Found" }

val SOME res = Web.runString app "GET /greet/alice HTTP/1.1\r\n\r\n"
```

Run the bundled end-to-end example (routing + middleware + HTML rendering over
hand-built requests):

```sh
make example
```

## Build & test

```sh
make test        # MLton
make test-poly   # Poly/ML
make all-tests   # both
```

**16 deterministic checks**, identical under MLton and Poly/ML.

> Note: as the umbrella vendors several libraries that themselves share lower
> deps (`sml-http`, `sml-uri`, `sml-parsec`, ...), the Poly/ML `tools/polybuild`
> wrapper deduplicates source files by canonical path — each opaquely-ascribed
> module must be elaborated exactly once across the diamond.

## Installation

```
package github.com/sjqtentacles/sml-web
require {
  github.com/sjqtentacles/sml-router
  github.com/sjqtentacles/sml-middleware
  github.com/sjqtentacles/sml-session
  github.com/sjqtentacles/sml-negotiate
  github.com/sjqtentacles/sml-html
  github.com/sjqtentacles/sml-forms
  github.com/sjqtentacles/sml-http
}
```

Dependencies are also vendored under `lib/github.com/sjqtentacles/` and
committed, so `make` needs no network.

## Layout

```
lib/github.com/sjqtentacles/sml-web/
  web.sig  web.sml          app type + run + negotiation helpers
  sources.mlb  sml-web.mlb
examples/app.sml            end-to-end example app
test/                       Harness suite (16 checks)
```

## The wider stack

This repo sits at the top of a layered set of small, pure, dual-compiler
`sml-*` libraries (foundations → protocol → web layer → umbrella). The one
documented impure edge is `sml-serve`, an MLton-only socket adapter (see the
plan) that drives an `sml-web` app against a real TCP listener — kept out of
this portable, deterministic core.

## License

MIT
