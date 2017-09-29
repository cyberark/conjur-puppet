type Conjur::Endpoint = Struct[{
  uri     => String[1],
  version => Integer,
  cert    => Optional[String[1]]
}]
