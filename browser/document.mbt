///|
priv struct BrowserDocument {
  manifest : @core.Manifest
  load : (String) -> Bytes raise
}

///|
fn BrowserDocument::part(self : BrowserDocument, hash : String) -> Bytes raise {
  (self.load)(hash)
}

///|
fn single_document(doc : @core.Document) -> BrowserDocument {
  { manifest: doc.manifest, load: fn(hash) { doc.part(hash) }, }
}
