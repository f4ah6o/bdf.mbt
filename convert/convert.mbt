///|
/// The @bdfkit/convert Worker message envelope, kept independent of its
/// TinyGo Wasm payload and browser-specific postMessage transport.
pub(all) enum Action {
  Convert
  Open
  Page(Int, Int)
  Finish(Int)
  Close(Int)
} derive(Debug, Eq)

///|
pub(all) struct ConvertOptions {
  format : String
  name : String
  password : String
  fonts : String
  pages : String
  params : Map[String, String]
}

///|
pub fn ConvertOptions::new() -> ConvertOptions {
  { format: "", name: "", password: "", fonts: "", pages: "", params: {} }
}

///|
pub(all) struct Request {
  id : Int
  action : Action
  options : ConvertOptions
}

///|
pub(all) enum PendingStatus {
  Waiting
  Completed
  Failed(String)
} derive(Debug, Eq)

///|
pub(all) struct Client {
  mut next_id : Int
  mut terminated : Bool
  pending : Map[Int, PendingStatus]
}

///|
pub suberror ConvertError {
  Terminated
  UnknownRequest
  InvalidInput(String)
}

///|
pub fn Client::new() -> Client {
  { next_id: 1, terminated: false, pending: {} }
}

///|
/// Match upstream's monotonic request IDs, leaving ID zero for startup.
pub fn Client::request(self : Client, action : Action, options : ConvertOptions) -> Request raise {
  if self.terminated {
    raise Terminated
  }
  match action {
    Page(stream, index) => {
      if stream <= 0 || index < 0 {
        raise InvalidInput("invalid stream or page")
      }
    }
    Finish(stream) | Close(stream) => {
      if stream <= 0 {
        raise InvalidInput("invalid stream")
      }
    }
    _ => ()
  }
  if self.next_id <= 0 || self.next_id == 2147483647 {
    raise InvalidInput("worker request ID exhausted")
  }
  let id = self.next_id
  self.next_id += 1
  self.pending.set(id, Waiting)
  { id, action, options }
}

///|
pub fn Client::reply(self : Client, id : Int, ok : Bool, error : String) -> Unit raise {
  if self.terminated {
    raise Terminated
  }
  match self.pending.get(id) {
    Some(Waiting) =>
      if ok {
        self.pending.set(id, Completed)
      } else {
        self.pending.set(id, Failed(error))
      }
    _ => raise UnknownRequest
  }
}

///|
pub fn Client::status(self : Client, id : Int) -> PendingStatus? {
  self.pending.get(id)
}

///|
pub fn Client::forget(self : Client, id : Int) -> Unit {
  self.pending.remove(id)
}

///|
pub fn Client::terminate(self : Client) -> Unit {
  self.terminated = true
  for id, status in self.pending {
    if status == Waiting {
      self.pending.set(id, Failed("converter terminated"))
    }
  }
}
