(* test.sml -- end-to-end sml-web tests over hand-built requests. *)

structure WebTests =
struct
  open Harness

  fun rawReq method target headers =
    let
      val hdrLines = String.concat (List.map (fn (k, v) => k ^ ": " ^ v ^ "\r\n") headers)
    in
      method ^ " " ^ target ^ " HTTP/1.1\r\n" ^ hdrLines ^ "\r\n"
    end

  fun run () =
    let
      val log = ref ([] : string list)

      val home : Router.handler = fn _ => fn _ => Http.text 200 "home"
      val showUser : Router.handler =
        fn _ => fn params =>
          Http.text 200 ("user " ^ (case List.find (fn (k,_) => k = "id") params of
                                        SOME (_, v) => v | NONE => "?"))
      val createUser : Router.handler = fn _ => fn _ => Http.text 201 "created"

      val app =
        Web.make
          { middleware =
              [ Middleware.logTo log
                  (fn (rq, rs) => #method rq ^ " " ^ #target rq ^ " " ^ Int.toString (#status rs))
              , Middleware.catchErrors (fn _ => Http.text 500 "err")
              , Middleware.addHeader "X-Powered-By" "sml-web" ]
          , routes =
              [ Router.get "/" home
              , Router.get "/users/:id" showUser
              , Router.post "/users" createUser ]
          , notFound = fn _ => Http.text 404 "not found" }

      fun req method target headers = valOf (Web.runString app (rawReq method target headers))

      (* ---- routing ---- *)
      val () = section "routing"
      val () = checkInt "root" (200, #status (req "GET" "/" []))
      val () = checkString "root body" ("home", #body (req "GET" "/" []))
      val () = checkString "param capture" ("user 42", #body (req "GET" "/users/42" []))
      val () = checkInt "post create" (201, #status (req "POST" "/users" []))
      val () = checkInt "unknown -> 404" (404, #status (req "GET" "/nope" []))
      val () = checkInt "wrong method -> 404" (404, #status (req "DELETE" "/" []))

      (* ---- middleware applied through the app ---- *)
      val () = section "middleware"
      val r = req "GET" "/" []
      val () = checkBool "powered-by header present"
        (true, Headers.get (#headers r) "x-powered-by" = SOME "sml-web")
      val () = checkBool "log captured all requests so far"
        (true, List.length (!log) > 0)
      val () = checkString "last log line"
        ("GET / 200", List.last (!log))

      (* ---- malformed input ---- *)
      val () = section "parsing"
      val () = checkBool "malformed request -> NONE"
        (true, not (isSome (Web.runString app "garbage\r\n\r\n")))

      (* ---- negotiation helpers ---- *)
      val () = section "negotiation"
      val accReq = valOf (Http.parseRequest
        (rawReq "GET" "/" [("Accept", "text/html;q=0.8, application/json")]))
      val () = checkBool "media picks json"
        (true, Web.negotiateMedia accReq ["text/html", "application/json"]
               = SOME "application/json")
      val langReq = valOf (Http.parseRequest
        (rawReq "GET" "/" [("Accept-Language", "fr-CH, fr;q=0.9, en;q=0.8")]))
      val () = checkBool "language picks fr"
        (true, Web.negotiateLanguage langReq ["en", "fr"] = SOME "fr")
      val encReq = valOf (Http.parseRequest
        (rawReq "GET" "/" [("Accept-Encoding", "gzip, deflate;q=0.5")]))
      val () = checkBool "encoding picks gzip"
        (true, Web.negotiateEncoding encReq ["gzip", "deflate"] = SOME "gzip")
      val noAcceptReq = valOf (Http.parseRequest (rawReq "GET" "/" []))
      val () = checkBool "media wildcard fallback when no Accept"
        (true, Web.negotiateMedia noAcceptReq ["text/html"] = SOME "text/html")

      (* ---- error handling through stack ---- *)
      val () = section "errors"
      val boomApp =
        Web.make
          { middleware = [ Middleware.catchErrors (fn _ => Http.text 500 "caught") ]
          , routes = [ Router.get "/boom" (fn _ => fn _ => raise Fail "kaboom") ]
          , notFound = fn _ => Http.text 404 "nf" }
      val () = checkInt "handler exception -> 500"
        (500, #status (valOf (Web.runString boomApp (rawReq "GET" "/boom" []))))
      val () = checkString "error body" ("caught",
        #body (valOf (Web.runString boomApp (rawReq "GET" "/boom" []))))
    in
      ()
    end
end
