(* examples/app.sml -- a small end-to-end sml-web app over hand-built requests.

   Demonstrates routing, params, a middleware stack (logging + security header
   + error catching), content negotiation, and HTML rendering -- all pure, no
   sockets. *)

val log = ref ([] : string list)

(* A typed page rendered with sml-html, escaped safely. *)
fun page title body =
  Html.render
    (Html.el "html" []
       [ Html.el "head" [] [ Html.el "title" [] [ Html.text title ] ]
       , Html.el "body" [] body ])

val home : Router.handler =
  fn _ => fn _ =>
    Http.response 200
      (Headers.fromList [("Content-Type", "text/html")])
      (page "Home" [ Html.el "h1" [] [ Html.text "Welcome to sml-web" ] ])

val greet : Router.handler =
  fn req => fn params =>
    let
      val who = case List.find (fn (k,_) => k = "name") params of
                    SOME (_, v) => v | NONE => "stranger"
    in
      Http.response 200
        (Headers.fromList [("Content-Type", "text/html")])
        (page "Greeting"
           [ Html.el "p" [] [ Html.text ("Hello, " ^ who ^ "!") ] ])
    end

val app =
  Web.make
    { middleware =
        [ Middleware.logTo log
            (fn (rq, rs) => #method rq ^ " " ^ #target rq ^ " -> " ^ Int.toString (#status rs))
        , Middleware.catchErrors (fn _ => Http.text 500 "Internal Error")
        , Middleware.addHeader "X-Powered-By" "sml-web" ]
    , routes =
        [ Router.get "/" home
        , Router.get "/greet/:name" greet ]
    , notFound = fn _ => Http.text 404 "Not Found" }

fun hit method target =
  case Web.runString app (method ^ " " ^ target ^ " HTTP/1.1\r\n\r\n") of
      NONE => print ("bad request: " ^ method ^ " " ^ target ^ "\n")
    | SOME res =>
        print (Int.toString (#status res) ^ " " ^ method ^ " " ^ target
               ^ " (" ^ Int.toString (String.size (#body res)) ^ " bytes)\n")

val () =
  ( hit "GET" "/"
  ; hit "GET" "/greet/alice"
  ; hit "GET" "/missing"
  ; print "--- access log ---\n"
  ; List.app (fn l => print (l ^ "\n")) (!log) )
